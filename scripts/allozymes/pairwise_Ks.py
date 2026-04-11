#!/usr/bin/env python3
from datetime import datetime
from Bio import SeqIO
import sys
import os
import argparse
import math
import dnds

# Some constants
PROG = sys.argv[0].split('/')[-1]
MIN_ALN_LEN = 25
ALN_SUFFIX = 'fa'
WIN_LEN = 9 # 3 codons

def parse_args():
    '''Set and verify command line options.'''
    p = argparse.ArgumentParser()
    p.add_argument('-l', '--sco-list',
                   required=True,
                   help='(str) Path to the single-copy orthgroup table \
                    (produced by `extract_orthogroups_cds.py`).')
    p.add_argument('-a', '--alignments',
                   required=True,
                   help='(str) Path to the directory with the trimmed \
                    multiple sequence alignments.')
    p.add_argument('-i', '--ingroup',
                   required=True,
                   help='(str) ID of the ingroup (focal) species in the alignment. \
                    Used to report gene/transcript IDs in the output.')
    p.add_argument('-o', '--out-dir',
                   required=False,
                   default='.',
                   help='(str) Path to output directory [default=./].')
    p.add_argument('-w', '--window-len',
                   required=False,
                   type=int,
                   default=WIN_LEN,
                   help=f'(int) Window length over which to calculate \
                     silent substitution rate (Ks) [default={WIN_LEN}]')
    p.add_argument('-m', '--min-aln-len',
                   required=False,
                   type=int,
                   default=MIN_ALN_LEN,
                   help=f'(int) Minimum length required to keep an \
                    alignment [default={MIN_ALN_LEN}]')
    p.add_argument('-s', '--aln-suffix',
                   required=False,
                   default=ALN_SUFFIX,
                   help=f'(str) Suffix for the alignment FASTA files \
                    [default={ALN_SUFFIX}].')

    # Check inputs
    args = p.parse_args()
    assert os.path.exists(args.sco_list)
    assert os.path.exists(args.alignments)
    args.alignments = args.alignments.rstrip('/')
    args.out_dir = args.out_dir.rstrip('/')
    assert os.path.exists(args.out_dir)
    # Set some constants
    return args

def date() -> str:
    '''Print the current date in YYYY-MM-DD format.'''
    return datetime.now().strftime("%Y-%m-%d")

def time() -> str:
    '''Print the current time in HH:MM:SS format.'''
    return datetime.now().strftime("%H:%M:%S")

def parse_sco_list(sco_f:str)->dict:
    '''
    Parse the Single Copy Orthogroup list file
    Args
        sco_f (str): Path to the Single Copy Orthogroup list file.
    Returns:
        sco_dict (dict): Dictionary with orthogroup IDs as keys and a 
                         pair of taxon-gene IDs as values.
        sco_dict = { orthogroup_id: { taxon_id : gene_id, 
                                      taxon_id : gene_id },
                     orthogroup_id: { taxon_id : gene_id, 
                                      taxon_id : gene_id }, }
    '''
    print('\nParsing Single Copy Orthogroup input table...', flush=True)
    sco_dict = {}
    records = 0
    taxa = []
    with open(sco_f, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip('\n')
            if line.startswith('#') or len(line)==0:
                continue
            records += 1
            fields = line.split('\t')
            sco_id = fields[0]
            taxon = fields[1]
            gene_id = fields[2]
            # Add the orthogroup ID to the dictionary if not already present
            sco_dict.setdefault(sco_id, {})
            sco_dict[sco_id][taxon] = gene_id
            # Add the taxon to the taxa list if not already present
            if taxon not in taxa:
                taxa.append(taxon)
    # Report to log
    print(f'    Parsed {records:,} records.')
    print(f'    Found {len(taxa):,} taxa: {", ".join(taxa)}.')
    print(f'    And {len(sco_dict):,} Single Copy Orthogroups.', flush=True)
    return sco_dict

def extract_sequences(in_msa_f:str, ingroup:str)->tuple[str, str]:
    '''
    Extract the sequences from an input MSA FASTA. The
    alignment must contain a max of two sequences.
    Args:
        in_msa_f (str): Path to input MSA FASTA
        ingroup (str): ID of ingroup focal species.
    Returns:
        (ingroup_seq, outgroup_seq): tuple of sequences for 
            the ingroup and outgroup taxa.
    '''
    ingroup_seq = ''
    outgroup_seq = ''
    ingroup_found = False
    count = 0
    # Parse the input fasta
    for record in SeqIO.parse(in_msa_f, 'fasta'):
        count += 1
        # Process if ingroup
        if record.id == ingroup:
            ingroup_found = True
            ingroup_seq = record.seq
        else:
            outgroup_seq = record.seq
    # Both sequences must be codons (length must be multiples of 3)
    if len(ingroup_seq)%3 != 0 or len(outgroup_seq)%3 != 0:
        sys.exit(f'Error: sequences in MSA must be in in-frame codons (multiples of 3):\n\
                 seq1: {len(ingroup_seq):,}\nseq2{len(outgroup_seq):,}')
    # The fasta must contain only two sequences.
    if count != 2:
        sys.exit(f'Error: MSA FASTA {in_msa_f} does not have two sequences.\
Alignment must only be between a pair of ingroup and outgroup sequences.')
    # The FASTA must contain the ingroup
    if not ingroup_found:
        sys.exit(f'Error: Ingroup sequence ID ({ingroup}) not found in input MSA FASTA:\
{in_msa_f}')
    # And the sequences must be of the same length
    if len(ingroup_seq) != len(outgroup_seq):
        sys.exit(f'Error: The sequences in {in_msa_f} are of unequal length.')
    return ingroup_seq, outgroup_seq

def calculate_windowed_Ks(seq1: str,
                          seq2: str,
                          sco_id: str,
                          window_len: int = WIN_LEN) -> list:
    '''
    Process a pair of sequences and calculate the windowed
    silent substitution rate (Ks) between them.
    Args:
        seq1 (str): Sequence, for ingroup
        seq2 (str): Sequence, for outgroup
        sco_id (str): Orthogroup ID
        window_len (int): Window length
    Returns:
        rows (list): List containing the per-row outputs.
    '''
    rows = []

    # Calculate the silent substitutions in the ingroup sequences
    silent_subs = calculate_silent_substitutions(seq1, seq2)

    for i, site in enumerate(silent_subs):
        row = [f'{sco_id}',         # Gene ID
               f'{site[0]}',        # Ingroup Site
               f'{site[1]}',        # Outgroup Site
               f'{site[2]}',        # Ingroup position
               f'{site[3]}',        # Codon Index
               f'{site[4]}',        # Position in codon
               f'{site[5]}',        # Differences in site
               f'{site[6]:0.8g}',   # Number of synonymous sites
               f'{site[7]:0.8g}',   # Number of synonymous substitutions
               f'{site[8]:0.8g}']   # Rate of synonymous substitutions
        row_str = '\t'.join(row)
        rows.append(row_str)

    # # Iterate across the windows:
    # for i in range(0, len(silent_subs), window_len):
    #     # Set the boundary coordinates
    #     j = i + window_len
    #     if j > len(silent_subs):
    #         j = len(silent_subs)
    #     # Subset to the specific window
    #     window_subs = silent_subs[i:j]
    #     n_silent_subs = sum(window_subs)
    #     # Window length based on ingroup ungapped sequence
    #     window_length = j - i
    #     # Proportion of silent substitutions
    #     Ks_raw = n_silent_subs / window_length if window_length > 0 else 0
    #     # Calculate using the Jukes-Cantor correction for silent sites
    #     try:
    #         Ks_adj = -(3/4) * math.log(1 - ((4/3) * Ks_raw))
    #     except ValueError:
    #         Ks_adj = math.nan
    #     row = f'{sco_id}\t{i+1}\t{j}\t{n_silent_subs}\t{Ks_raw:0.8g}\t{Ks_adj:0.8g}'
    #     rows.append(row)
    return rows

def calculate_silent_substitutions(seq1: str, seq2: str) -> list:
    '''
    Process a pair of ingroup and outgroup sequences, and
    tally the synonymous (silent) substitutions at each position of the ingroup.
    Args:
        seq1 (str): Sequence, for ingroup
        seq2 (str): Sequence, for outgroup
    Returns:
        syn_subs (list): List of per-position silent substitutions
            (1=silent sub, 0=no silent sub).
    '''
    # First, determine the length of the ingroup sequence ignoring gaps
    ingrp_len = len(seq1.replace('-', ''))
    # Initialize the tally of silent substitutions
    # syn_substitutions = [ math.nan for _ in range(ingrp_len) ]
    syn_substitutions = []

    # Create a map between the positions of the gapped alignment and the
    # un-gapped ingroup sequence.
    gap_map = {}
    ungap_pos = 0
    for pos, site in enumerate(seq1):
        if site != '-':
            gap_map[pos] = ungap_pos
            ungap_pos += 1
    assert ingrp_len == ungap_pos

    # Loop over the aligned codons
    codon_i = 0
    for i in range(0, len(seq1), 3):
        j = i+3
        if j > len(seq1):
            j = len(seq1) # This should never happen
        codon1 = seq1[i:j]
        codon2 = seq2[i:j]
        # Skip gaps
        if '-' in codon1 or '-' in codon2:
            continue
        # Skip uncalled bases
        if 'N' in codon1 or 'N' in codon2:
            continue

        # Process the codons
        syn_sites = math.nan
        syn_subs = math.nan
        syn_rate = math.nan
        try:
            syn_sites = dnds.syn_sum(codon1, codon2)
            syn_subs, _ = dnds.substitutions(codon1, codon2)
        except:
            x = 0
        syn_rate = math.nan
        if syn_sites>0:
            syn_rate = float(syn_subs/syn_sites)

        # If there are substitutions, try to map them to the
        # corresponding position in the sequence
        ndiffs = 0
        for p in range(3):
            diff = 0
            if codon1[p] != codon2[p]:
                ndiffs += 1
                diff = 1
            # Find the position in the map
            m = gap_map[i+p]
            site_info = (codon1[p],         # Ingroup site
                         codon2[p],         # Outgroup site
                         m,                 # Mapped position in ingroup sequence
                         codon_i,           # Codon index in ingroup
                         p+1,               # Position in codon
                         diff,              # Differences in site
                         float(syn_sites),  # Number of Synonymous sites
                         syn_subs,          # Number of Synonymous substitutions
                         syn_rate)          # Synonymous substitution rate, K_s
            # syn_substitutions[m] = site_info
            syn_substitutions.append(site_info)
        codon_i += 1
    return syn_substitutions

def process_orthogroups(sco_list:dict,
                        ingroup:str,
                        alignments:str,
                        outdir:str='.',
                        window_len:int=WIN_LEN,
                        min_aln_len:int=MIN_ALN_LEN,
                        aln_suffix:str=ALN_SUFFIX)->None:
    '''
    Process the alignments for all orthogroups. Extract sequences,
    calculate silent substitution rates (Ks), and report.
    Args:
        sco_dict (dict): Dictionary with orthogroup IDs as keys and a
                pair of taxon-gene IDs as values.
        ingroup (str): ID of ingroup focal species.
        alignments (str): Path to the alignment files.
        out_dir (str): Path to output directory [default=.].
        window_len (int): Window length to perform calculations.
        min_aln_len (int): Minimum length required to keep an
                           alignment [default=MIN_ALN_LEN].
        aln_suffix (str): Suffix for all MSA fasta files.
    '''
    print('\nProcessing orthogroups for silent substitution analysis...', flush=True)
    print(f'    Looking for multiple-sequence alignment FASTAs in the following format\n\
        {alignments}/<OrthologID>.{aln_suffix}', flush=True)
    # Prepare outputs
    out_tsv = f'{outdir}/silent_substitutions_{ingroup}.tsv'
    with open(out_tsv, 'w', encoding='utf-8') as fh:
        header = ['GeneID',
                  'InGrpSite',
                  'OutGrpSite',
                  'InGrpPos',
                  'CodonIndex',
                  'PosInCodon',
                  'DiffsInSite',
                  'SynSitesN',
                  'SynSubsN',
                  'SynSubsRate']
        header = '\t'.join(header)
        fh.write(f'{header}\n')

        # Loop over all orthogroups
        n_found = 0
        n_processed = 0
        for sco_id in sco_list:
            # Select the genes for the focal taxon
            sco_genes = sco_list[sco_id]
            gene = sco_genes.get(ingroup, None)
            if gene is None:
                sys.exit(f'Error: {ingroup} not found among the taxa for orthogroup {sco_id}')
            # Select the input multiple sequence alignment and
            # extract the input sequences.
            in_msa_f = f'{alignments}/{sco_id}.{aln_suffix}'
            # Some of these MSAs will not exists. This is expected.
            # Just skip them.
            if not os.path.exists(in_msa_f):
                continue
            n_found += 1
            ingroup_seq, outgroup_seq = extract_sequences(in_msa_f, ingroup)
            # Skip sequences if they are too small
            if len(ingroup_seq) < min_aln_len:
                continue
            # Calculate the pairwise silent substitutions (Ks) over a set of windows
            rows = calculate_windowed_Ks(ingroup_seq,
                                        outgroup_seq,
                                        sco_id,
                                        window_len)
            
            for row in rows:
                fh.write(f'{row}\n')
            n_processed += 1

    # Report to log.
    print(f'\nFound alignments for a total of {n_found:,} orthogroups.',
          flush=True)
    print(f'    Calculated silent substitution rates (Ks) for {n_processed} pairs of sequences.',
          flush=True)

def main():
    print(f'{PROG} started on {date()} {time()}.')
    # Parse args
    args = parse_args()
    print(f'\nReporting Ks for {args.ingroup}')

    # Parse the Single Copy Orthologues list
    sco_list = parse_sco_list(args.sco_list)

    # Process all the orthogroups
    process_orthogroups(sco_list,
                        args.ingroup,
                        args.alignments,
                        args.out_dir,
                        args.window_len,
                        args.min_aln_len,
                        args.aln_suffix)

    # Done!
    print(f'\n{PROG} finished on {date()} {time()}.')

# Run Code
if __name__ == '__main__':
    main()
