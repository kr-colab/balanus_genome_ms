#!/usr/bin/env python3
import sys, os, argparse, datetime, gzip

#
# Globals
#
DATE = datetime.datetime.now().strftime("%Y%m%d")
PROG = sys.argv[0].split('/')[-1]
DESC = 'Process an input FASTA along with annotations to rename the sequences and sort the output.'
MIN_CHR_LEN = 1_000_000 # Minimum length to label a sequence as a chromosome
MIN_SEQ_LEN = 1_000     # Minimum length to export a sequence

#
# Command line options
#
def parse_args():
    p = argparse.ArgumentParser(prog=PROG, description=DESC)
    p.add_argument('-f', '--in-fasta', required=True, help='(str) Path to input FASTA.')
    p.add_argument('-i', '--in-fai', required=True, help='(str) Path to input FASTA index (FAI).')
    p.add_argument('-k', '--name-key', required=False, default=None, help='(str) Path to name key file.')
    p.add_argument('-o', '--out-dir',  required=False, default='.', help='(str) Output directory.')
    p.add_argument('-b', '--basename', required=False, default=DATE, help='(str) Name of current run. Defaults to datetime.')
    p.add_argument('-m', '--min-chr-len', required=False, default=MIN_CHR_LEN, type=float, help=f'(int/float) Minimum length of sequence to label as a chromosome.  [default = {MIN_CHR_LEN:,}]')
    p.add_argument('-g', '--gtf', required=False, default=None, help='(str) Path to input GTF/GFF3.')
    p.add_argument('-l', '--min-seq-len', required=False, default=MIN_SEQ_LEN, type=float, help=f'(int/float) minimum length needed to export a sequence.  [default = {MIN_SEQ_LEN:,}]')
    p.add_argument('--rename-by-length', action='store_true', help='Rename the chromosome sequences by their length in BP (i.e., longest sequences is chromosome 1).')
    p.add_argument('--export-sorted', action='store_true', help='Export the sequences sorted by size. Defaults to the order of sequences in the FAI.')

    # Check input arguments
    args = p.parse_args()
    args.out_dir = args.out_dir.rstrip('/')
    assert os.path.exists(args.out_dir)
    assert os.path.exists(args.in_fasta)
    assert os.path.exists(args.in_fai)
    if args.name_key is not None:
        assert os.path.exists(args.name_key)
    if args.gtf is not None:
        assert os.path.exists(args.gtf)
    assert args.min_chr_len > 0
    assert args.min_seq_len > 0
    # If renaming by length, output must be sorted
    if args.rename_by_length:
        args.export_sorted = True
    return args

def parse_name_key(name_key_f):
    '''Parse the file containing the renaming key'''
    if name_key_f is None:
        return None
    name_key = dict()
    with open(name_key_f) as fh:
        for line in fh:
            line = line.strip('\n')
            if line.startswith('#') or len(line) == 0:
                continue
            fields = line.split('\t')
            assert len(fields) == 2
            old_name = fields[0]
            new_name = fields[1]
            name_key[old_name] = new_name
    print(f'Loaded renaming key for {len(name_key):,} sequences.\n', flush=True)
    return name_key

def parse_fai(fai_f):
    '''Parse the FASTA index file'''
    seq_lens = dict()
    with open(fai_f) as fh:
        for line in fh:
            line = line.strip('\n')
            if line.startswith('#') or len(line) == 0:
                continue
            fields = line.split('\t')
            assert len(fields) == 5 # FAI files must have 5 columns
            seq_id = fields[0]
            seq_len = int(fields[1])
            seq_lens[seq_id] = seq_len
    print(f'Loaded name/length information for {len(seq_lens):,} sequences in the FAI file.\n', flush=True)
    return seq_lens

def read_fasta(fasta_f):
    '''Read the sequence information from a FASTA file'''
    print('Loading genome FASTA...')
    # Check input file
    fasta_dict = dict()
    total_len = 0
    with gzip.open(fasta_f, 'rt') if fasta_f.endswith('.gz') else open(fasta_f) as f:
        name = None
        seq = []
        for line in f:
            line = line.strip('\n')
            # Ignore empty lines
            if len(line) == 0:
                continue
            # Check if its ID or sequence
            if line[0] == '>':
                if name is not None:
                    full_seq = ''.join(seq)
                    fasta_dict[name] = full_seq
                    total_len += len(full_seq)
                name = line[1:].split()[0]
                seq = []
            elif line[0] in ['#', '.']:
                # Ignore comment lines
                continue
            else:
                # if it is sequence
                seq.append(line.upper())
    full_seq = ''.join(seq)
    fasta_dict[name] = full_seq
    total_len += len(full_seq)
    # Print to log:
    print(f'    Read file: {fasta_f}\n    Composed of {len(fasta_dict):,} sequence(s) with total length of {total_len:,} bp.\n')
    return fasta_dict

def filter_fasta(genome_dict, fai_dict, basename, name_key=None, min_chr_len=MIN_CHR_LEN, min_seq_len=MIN_SEQ_LEN, rename_by_length=False, export_sorted=False, fa_line_width=60):
    '''Apply filters and export a new FASTA sequence'''
    print('Processing output FASTA...')
    # Generate new output files
    fa_out = open(f'{basename}.fasta', 'w')
    tsv_out = open(f'{basename}.info.tsv', 'w')
    tsv_out.write('#SeqIdx\tSeqNewName\tSeqOldName\tSeqLenBP\n')
    # Return a dictionary of old name/new name pairs
    name_pairs = dict()
    # For logs
    total_len = 0
    n_seqs = 0
    n_chrs = 0
    # Temp for naming records
    # For general sequences
    n_large_seqs = sum([ 1 if fai_dict[k] > min_seq_len else 0 for k in fai_dict ])
    scaf_id_pad = len(str(n_large_seqs))
    n_chr_seqs = sum([ 1 if fai_dict[k] > min_chr_len else 0 for k in fai_dict ])
    chr_id_pad = len(str(n_chr_seqs))
    # Prepare the input sequence records
    records = fai_dict.keys()
    # If exporting sorted sequences
    if export_sorted:
        records = [ k for k, _ in sorted(fai_dict.items(), key=lambda x:x[1], reverse=True) ]
    # Loop over the sequences
    for i, record in enumerate(records):
        # The length of the sequence
        seq_len = fai_dict.get(record, None)
        assert seq_len is not None, f'Error: {record} not in FAI'
        # The nucleotide sequence
        sequence = genome_dict.get(record, None)
        assert sequence is not None, f'Error: {record} not in FASTA'
        # Filter sequences if too small
        if seq_len < min_seq_len:
            continue
        # Increase the tallies
        n_seqs += 1
        total_len += seq_len
        # Process names
        old_name = record
        new_name = record # By default, names are not changed
        # Change the name by the length
        if rename_by_length:
            new_id = str(n_seqs).zfill(scaf_id_pad)
            new_name = f'scaffold{new_id}'
            if seq_len > min_chr_len:
                new_id = str(n_seqs).zfill(chr_id_pad)
                new_name = f'chr{new_id}'
                n_chrs += 1
        # When there's a name key and the sequence is in it
        if name_key is not None:
            if record in name_key:
                new_name = name_key[record]
        # Write the changes of the record to the TSV
        row = f'{n_seqs}\t{new_name}\t{old_name}\t{seq_len}\n'
        tsv_out.write(row)
        # Write FASTA
        fa_out.write(f'>{new_name}\n')
        # Wrap the sequence lines up to `fa_line_width` characters
        start = None
        for start in range(0, seq_len, fa_line_width):
            seq_line = sequence[start:(start+fa_line_width)]
            fa_out.write(f'{seq_line}\n')
        # Save the name pairs
        name_pairs[old_name] = new_name
    # Report to logs
    print(f'    Exported {n_seqs:,} sequences (including {n_chrs:,} chromosomes), with a total length of {total_len:,} bp.\n')
    # Close outputs
    fa_out.close()
    tsv_out.close()
    return name_pairs

def process_gtf(gtf_f, basename, name_pairs):
    '''Process the GTF/GFF to rename chromosome IDs'''
    print('Processing GTF/GFF...')
    # Determine if input is a GTF or a GFF
    suffix = None
    f = gtf_f.rstrip('.gz')
    if f.endswith('gff'):
        suffix = 'gff'
    elif f.endswith('gff3'):
        suffix = 'gff3'
    elif f.endswith('gtf'):
        suffix = 'gtf'
    else:
        sys.exit(f"Error: input file `{gtf_f}` is of unknown type (non GTF/GFF/GFF3).")
    print(f'    Input file is of type: {suffix}.')
    records = 0
    # Determine the new output based on the suffix
    f_out = open(f'{basename}.{suffix}', 'w')
    f_out.write(f'## {DATE}\n## {PROG}\n')
    # Parse the input file and change the chromosome names based on the name pairs key
    with gzip.open(gtf_f, 'rt') if gtf_f.endswith('.gz') else open(gtf_f) as f:
        for i, line in enumerate(f):
            line = line.strip('\n')
            # Skip comments and empty lines
            if len(line) == 0:
                continue
            if line.startswith('#'):
                continue
            records += 1
            fields = line.split('\t')
            old_chr_name = fields[0]
            # Make sure that the previous name is in the key
            new_chr_name = name_pairs.get(old_chr_name, 'None')
            if new_chr_name is None:
                sys.exit(f"Error: Sequence ID in line {i} not in name pairs key. Make sure IDs in the FASTA and GTF/GFF match.")
            fields[0] = new_chr_name
            row = '\t'.join(fields)
            f_out.write(f'{row}\n')
    print(f'    Rename sequence IDs for {records:,} GTF/GFF records.')
    f_out.close()

def now():
    '''Print the current date and time.'''
    return f'{datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}'

def main():
    args = parse_args()
    print(f'{PROG} started on {now()}\n')
    # Prepare the basename
    basename = f'{args.out_dir}/{args.basename}'
    # Parse name key file
    name_key = parse_name_key(args.name_key)
    # Parse the FAI
    fai = parse_fai(args.in_fai)
    # Load the FASTA
    genome = read_fasta(args.in_fasta)
    # Process the sequences
    name_pairs = filter_fasta(genome, fai, basename, name_key, args.min_chr_len, args.min_seq_len, args.rename_by_length, args.export_sorted)
    # Process the GTF/GFF3 if needed
    if args.gtf is not None:
        process_gtf(args.gtf, basename, name_pairs)


    print(f'\n{PROG} finished on {now()}')


# Run Code
if __name__ == '__main__':
    main()
