# Barnacle genome paper

Working repository for the Pacific acorn barnacle (*Balanus glandula*) genome paper.

## *Balanus glandula* genome assembly and annotation

* The Pacfic acorn barnacle (*Balanus glandula*).
* NCBI TaxID: [110520](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=110520)

### Sample information and sequencing.

#### PacBio HiFi

Sample is one of several individuals collected on Feb 2023 by Erin Jezuit and George von Dassow at the Oregon Institute of Marine Biology, Charleston OR ([map](https://maps.app.goo.gl/8bmcutaaJussMBcy5)).

<!--- Confirm dates and locations of original --->

DNA was extracted with PacBio Nanobind and sequenced on three runs of PacBio HiFi at the University of Oregon's GC3F.

Path to raw data (all paths on `Poppy`):

```
/sietch_colab/data_share/balanus/hifi/read_links
```

#### Hi-C

One of several individuals collected on August 2023 by the Kern-Ralph co-lab at Cape Perpetua, OR ([map](https://maps.app.goo.gl/NjL9mCNNjerpXvnY7)).

<!--- Cape Perpetua or Bob Creek? --->

Tissue was processed by Phase Genomics into a Hi-C library and 2x150bp sequenced on an Illumina NovaSeq 6000 at the University of Oregon's GC3F.

Path to raw data:

```
/sietch_colab/data_share/balanus/hi-c/7549
```

#### RNAseq & Iso-Seq

One of several individuals collected on August 2023 by the Kern-Ralph co-lab at Cape Perpetua, OR ([map](https://maps.app.goo.gl/NjL9mCNNjerpXvnY7)).

<!--- Cape Perpetua or Bob Creek? --->

For RNAseq, whole-tissue RNA was extracted, prepared into two libraries (testes and cirri?) and sequenced (2x150bp) on an Illumina NovaSeq 6000 at the University of Oregon's GC3F.

<!--- Confirm tissue --->

Path to raw reads:

```
/sietch_colab/data_share/balanus/rna-seq/raw
```

For Iso-Seq, RNA was extracted from cirri and testes, and sequenced on a PacBio SMRTcell at he University of Oregon's GC3F.

Path to raw reads:

```
/sietch_colab/data_share/balanus/isoseq/6885/ccs.Q20
```

### Genome assembly

The directory `scripts/genome_assembly/` contains different directories each containing 
scripts describing different steps of the assembly and annotation.

#### K-mer estimation

The directory `scripts/genome_assembly/kmer_stats` contains the scripts for the k-mer 
analysis of genome size and heterozygosity.

* `run_jellyfish.sh`:
 
Use `jellyfish` version `2.1.10` to count k-mers (`jellyfish count`)
and generate a k-mer histogram (`jellyfish histo`).

* `run_genomescope.sh`

Use `GenomeScope2` version `2.0` to do the k-mer model and plot.

#### Initial contig-level assembly

The raw HiFi reads were assemblied using `hifiasm` version `0.19.6-r595` using default parameters.

```sh
cmd=(
    hifiasm
    -o $name
    -t 24
    $reads/m64047_230524_205253.ccs.fastq.gz
    $reads/m64047_230531_210842.ccs.fastq.gz
    $reads/m64047_230602_080338.ccs.fastq.gz
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1

# Convert the GFA to fasta
cat ${name}.bp.p_ctg.gfa | awk '/^S/{print ">"$2;print $3}' | \
    gzip > ${name}.p_ctg.fasta.gz
```

Path to this data:
```
/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def
```

This assembly was composed of 4,212 con tigs, with a total length of 1.64 Gbp, and a contig N50 of 734 Kbp. Largest contig was 4.25 Mbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237` (notice the 50% BUSCO duplicates).

```
## lineage: arthropoda_odb10
S:45.31%, 459
D:50.35%, 510
F:0.79%, 8
I:0.00%, 0
M:3.55%, 36
N:1013
```

#### Filtering for contamination

We filtered both this base genome and the raw PacBio HiFi reads for contamination using `blobtoolkit` version `4.3.0`.

First, we created a new BlobTools database:

```sh
cmd=(
    blobtools create
    --fasta $fasta
    --meta $meta
    --taxid $taxid
    --taxdump $taxdump
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}"
```

We specificed the NCBI taxid as `110520` (entry for *B. glandula*). Taxdump files downloaded on 2023-12-13.

To obtain depth of coverage, we aligned the HiFi reads to the contigs using `minimap2` version `2.26-r1175`.

```sh
# Align
minimap2 -x map-hifi -t $thr -a $fasta $reads | \
    samtools view -bh -@ $thr | \
    samtools sort -m 1G -@ $thr -o $alignments

# Index
cd $work/alignments
samtools index --csi --threads $thr $alignments
```

We added the coverage to the BlobTools database:

```sh
cmd=(
    blobtools add
    --cov ${bam}
    --cov "${bam}=def_3cell"
    --threads $thr
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}"
```

To assign taxonomy, we queried the contig-level assembly against NCBI's `nt` database (downloaded on 2023-12-13).

```sh
cmd=(
    blastn
    -query $genome
    -db $db
    -out -
    -evalue "1e-10"
    -outfmt "6 qseqid staxids bitscore std"
    -max_target_seqs 25
    -num_threads $thr
)

# Run BLASTN and compress output
"${cmd[@]}" | gzip > "${outf}"
```

We added the BLAST results to the BlobTools database:

```sh
cmd=(
    blobtools add
    --hits $blast
    --taxdump $taxdump
    --taxrule bestsumorder
    --threads $thr
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}"
```

Using the hits, we filtered the genome to include only sequences that were tagged to the taxonomical level "class Thecostraca". We also exported the IDs of all the reads that aligned to the contigs that matched to "class:Thecostraca".


```sh
# Output directory for the specific filter ()
lvl=class
filt=Thecostraca
rule=bestsumorder
suffix=filtered_${lvl}-${filt}
outd=$(date +${work}/%Y%m%d.balGla_def.filter_${lvl}-${filt}.BlobDir)
log=${outd}/${suffix}.log
tbl=${outd}/${suffix}.tbl
param=${rule}_${lvl}--Keys=${filt}
mkdir -p $outd

cmd=(
    blobtools filter
    --param $param
    --fasta $fasta
    --fastq $fastq
    --cov $bam
    --taxdump $taxdump
    --taxrule $rule
    --output $outd
    --suffix $suffix
    --invert # since we are keeping the matches to the filter
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}" > $log
```

Use used the generated read IDs to subset the original FASTQ to obtain only the desired HiFi reads using `seqtk` version `1.4-r130-dirty`.

```sh
seqtk subseq ../m64047_blaGla.merged.ccs.fastq.gz ./Thecostraca/
filtered_class-Thecostraca.reads.txts
```

We also filtered the ONT reads by alignming them to the `blobtools` filtered genome and retaining only the reads that aligned.

#### Generating updated contig-level assembly

Using the filtered, Thecostraca-specific reads we generated a new contig-level assembly using `hifiasm` version `0.19.8-r603`. This run included both ONT and Hi-C data, and has more strict parameters for the purging of haplotig sequences.

```sh
# Main hifiasm command
cmd=(
    hifiasm
    -o $name
    -t 36
    -s 0.25   # Min 25% similarity for haplotigs
    --hom-cov 68
    --hg-size 800m
    --dual-scaf
    --purge-max 68
    -D 10.0
    --ul $ul   # ONT reads
    --h1 $hc1  # Hi-C read 1 
    --h2 $hc2  # Hi-C read 2
    $hifidir/m64047_blaGla.merged.ccs.filtered_class-Thecostraca.fastq.gz
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1

# Convert the GFA to fasta
cat ${name}.hic.p_ctg.gfa | awk '/^S/{print ">"$2;print $3}' | \
    gzip > ${name}.p_ctg.fasta.gz
```

This assembly is composed of 2,218 contigs, with a total length of 1.29 Gbp, a largest contig of 6.37 Mbp, and a contig N50 of 1.16 Mbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237` (95.36% complete). Duplicates went down to 21% form 50%.

```
## lineage: arthropoda_odb10
S:73.54%, 745
D:21.82%, 221
F:0.89%, 9
I:0.00%, 0
M:3.75%, 38
N:1013
```

### Purging haplotig sequences

We purges haplotig sequences using `purge_dups` version `1.2.5`.

First, aligned the PacBio HiFi to the genome and did the assembly self-alignment using `minimap2` version `2.26-r1175`.

```sh
# Align the reads to the reference
minimap2 -x map-hifi -t 16 $genome $reads | gzip -c - > $paf

# Calculate read-depth histogram
pbcstat -O $alns_out $paf

# Calculate base-level depth
calcuts PB.stat > cutoffs 2>calcults.log

# Do an assembly self-alignment
split_fa $genome > $split
minimap2 -x asm5 -t 16 -DP $split $split | gzip -c - > $self
```

We then tan `purge_dups` and the `get_seqs` utility to identify and filter haplotig sequences.

```sh
# Mark the duplicates in a bed file
cmd=(
    purge_dups
    -2
    -T $alns/cutoffs
    -c $alns/PB.base.cov
    $paf
)
echo "${cmd[@]}"
"${cmd[@]}" > dups.bed 2> purge_dups.log

# Process the assembly
cmd=(
    get_seqs
    -e
    -s
    -p $name
    dups.bed
    $geno
)
echo "${cmd[@]}"
"${cmd[@]}" > get_seqs.log 2>&1
```

The purged assembly is composed of 1,342 contigs, a total length of 1.05 Gbp,largest contig of 6.37 Mbp, and a contig N50 of 1.35 Mbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237` (93.88% complete.)

```
## lineage: arthropoda_odb10
S:89.04%, 902
D:4.84%, 49
F:1.18%, 12
I:0.00%, 0
M:4.94%, 50
N:1013
```

In comparison with the un-purged assembly:

* Number of contigs went from 2.2 K to 1.3 K
* Total length went from 1.29 Gbp to 1.05 Gbp
* Contig N50 went from 1.16 Mbp to 1.31 Mbp
* BUSCO C went from 95.36% to 93.88%
* BUSCO D went from 21.82% to 4.84%

<!--- TODO --->

### Hi-C scaffolding

After haplotig purging, the contigs were assembled using Hi-C data. The alignment and processing of Hi-C read pairs was done following the Omni-C pipeline ([link](https://omni-c.readthedocs.io/en/latest/fastq_to_bam.html)), in accordance to the `yahs` documentation.

Path to this data:

```sh
/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c/yahs-scaffolding
```

#### Aliging Hi-C reads

The raw Hi-C reads were aligned to the genome using `bwa` version `0.7.17-r1188`. The base alignments were processed using `samtools` version `1.18`.

For `bwa`, we are splitting alignments and skipping mate rescue and pairing.

```sh
# Index the reference genome
echo "Indexing reference..."
bwa index -p $db $fasta

# Align and and store the "base" alignment
echo "Aligning reads..."
bwa mem -5SP -T0 -t $thr $db $r1 $r2 | \
    samtools view -bh -@ $thr -o $base_bam
```

#### Processing Hi-C read pairs

Following alignment and base processing, the aligned Hi-C read pairs were processed with `pairtools` version `1.0.2` in order to:

1) Record valid ligation events (`pairtools parse`)
2) Sorting the pairs (`pairtools sort`)
3) Remove PCR duplicates (`pairtools dedup`)
4) Splitting into corresponding aligment and read pairs file (`pairtools split`)

```sh
samtools view -h $base_bam | \
    pairtools parse --min-mapq 40 --walks-policy 5unique --max-inter-align-gap 30 \
        --nproc-in $npr --nproc-out $npr --chroms-path $geno | \
    pairtools sort --tmpdir $tmp --nproc $npr | \
    pairtools dedup --nproc-in $npr --nproc-out $npr --mark-dups --output-stats $dups | \
    pairtools split --nproc-in $npr --nproc-out $npr --output-pairs $pairs --output-sam - | \
    samtools view -bS -@ $npr | \
    samtools sort -@ $npr -o $proc_bam

# Index the final bam
echo "Indexing BAM..."
samtools index -@ $thr $proc_bam
```

#### Scaffolding the genome

Following alignment, the contigs were scaffolded using `yahs` version `1.2a.1`.

Since the contigs are fragmented, we reduced the minimum size of in `-r` to 1,000.

```sh
cmd=(
    yahs
    -o $outp
    -q 10
    -r 1000,5000,10000,20000,50000,100000,200000,500000,1000000,2000000,5000000,10000000,20000000,50000000,100000000,200000000,500000000
    $fasta
    $bam
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1
```

#### Generating contact map

Following the `yahs` documentation, we generated a contact map using `juicer pre` version `1.1` and `juicer tools` version `1.9.9`.

First, the base contact map (`*.hic` files) were generated:

```sh
# Juicer pre to  make the juicer input
juicer pre $bin $agp $fai 2> $log | \
    LC_ALL=C sort -k2,2d -k6,6d -T $outd --parallel=8 -S32G | \
    awk 'NF' > ${outb}.part
mv ${outb}.part ${outb}.sorted.txt

# Get the adjusted chr sizes
cat $log | grep "PRE_C_SIZE" | cut -d' ' -f2- > $chrom_sizes

# Run the actual juicer tools
juicer_tools pre \
    ${outb}.sorted.txt \
    ${outb}.hic.part \
    $chrom_sizes
mv ${outb}.hic.part ${outb}.out.hic
```

Then, we generated the `*.assembly` files, which can be edited using `juicebox`.

```sh
# Prepare the juicer pre run with assembly (-a) mode
outf=${outb}.jbat
log=${outf}.log
juicer pre -a -o $outf $bin $agp $fai > $log 2>&1

# Extract the adjusted assembly size
asm_size=${outb}.assembly_size.tsv
cat $log | grep "PRE_C_SIZE" | cut -d' ' -f2- > $asm_size

# Rerun juicer_tools with the new files
juicer_tools pre ${outf}.txt ${outf}.hic.part $asm_size
mv ${outf}.hic.part ${outf}.hic
```

#### Validating the scaffolded assembly

Checked with `quast` version `5.2.0`

| statistic | value |
| --------- | ----- |
| Total size | 1.05 Gbp |
| # scaffolds | 626 |
| # contigs | 1,878 |
| Largest scaffold | 79.9 Mbp |
| Scaffold N50 | 34.2 Mbp |
| Contig N50 | 1.2 Mbp |
| Scaffold L50 | 10 |

We verified gene-completeness using `compleasm` version `0.12-r237` (94.18% complete.)

```
## lineage: arthropoda_odb10
S:89.44%, 906
D:4.74%, 48
F:0.99%, 10
I:0.00%, 0
M:4.84%, 49
N:1013
```

#### Manual curation of the contact map

Did some manual correction using `juicebox` version `2.17.00`, primarily doing large-scale changes.

Re-generated the assembly using `juicer post`:

```sh
cmd=(
    juicer post
    -o $name
    $assm
    $agp
    $ctgs
)
echo "${cmd[@]}"
"${cmd[@]}"
```

Resulting in:

Checked with `quast` version `5.2.0`

| statistic | value |
| --------- | ----- |
| Total size | 1.05 Gbp |
| # scaffolds | 650 |
| # contigs | 1,900 |
| Largest scaffold | 80.3 Mbp |
| Scaffold N50 | 50.96 Mbp |
| Contig N50 | 1.18 Mbp |
| Scaffold L50 | 9 |

We verified gene-completeness using `compleasm` version `0.12-r237` (93.98% complete).

```
## lineage: arthropoda_odb10
S:89.24%, 904
D:4.74%, 48
F:0.89%, 9
I:0.00%, 0
M:5.13%, 52
N:1013
```

### Inspector

We performed one additional round of curation using `inspector` version `1.0.1`.

```sh
# Inspector evaluate
cmd=(
    inspector.py
    --contig $fasta
    --read $hifi
    --thread $thr
    --outpath $outdir
    --datatype "hifi"
)
echo "${cmd[@]}"
"${cmd[@]}"

# Inspector correct
cmd=(
    inspector-correct.py
    --inspector $outdir
    --outpath $cordir
    --datatype "pacbio-hifi"
    --thread $thr
)
echo "${cmd[@]}"
"${cmd[@]}"
```

#### Stats

Checked with `quast` version `5.2.0`

| statistic | value |
| --------- | ----- |
| Total size | 1.04 Gbp |
| # scaffolds | 592 |
| # contigs | 1,802 |
| Largest scaffold | 80.3 Mbp |
| Scaffold N50 | 51.41 Mbp |
| Contig N50 | 1.18 Mbp |
| Scaffold L50 | 9 |
| Total len > 1 Mbp | 906.6 Mbp |
| Fragments > 1 Mbp | 58 |
| % len >  1 Mbp | 86.74% |
| Total len > 8.5 Mbp | 841.2 Mbp |
| Fragments > 8.5 Mbp | 16 |
| % len >  10 Mbp | 80.61% |

We verified gene-completeness using `compleasm` version `0.12-r237` (94.08 % complete.)

```ls
## lineage: arthropoda_odb10
S:89.44%, 906
D:4.64%, 47
F:0.89%, 9
I:0.00%, 0
M:5.03%, 51
N:1013
```

### Genome annotation

#### Repeat annotation

Done with `EarlGrey` version `4.0.1`.

First, we downloaded `Dfam 3.8` and extracted the repeat sequences for Arthropoda. These were used as an initial repeat database for `EarlGrey`.

```sh
# Existing starting databse
# This is the files extracted from Dfam 3.8
# 6657 is for Crustacea
taxid=6657
rep_db=$work/Repbase_db/dfam3.8_${taxid}.fa
# Set the input sequence
in_fasta=${work}/in_genome/BalGla.fasta
# Search term
term=arthropoda
# Target Species name
name="BalGla"
# Make an output directory for run
outp=$(date +${work}/%y%m%d.earl_grey.${term}.${taxid})
mkdir -p $outp
cd $outp

# Repeat Masker command
cmd=(
    earlGrey
    -g $in_fasta
    -s $name
    -o $outp
    -t $thr
    -l $rep_db # Starting consensus library for an inital mask
    -r $term   # RepeatMasker search term
    -c yes     # Cluster TE library to reduce redundancy
    -d yes     # Create soft-masked genome
)

echo "${cmd[@]}"
"${cmd[@]}"
```

Results:

| tclassif | cov | count | proportion | gen | N Distinct Classifications |
| -------- | --- | ----- | ---------- | --- | -----| 
| DNA | 88203702 | 217040 | 0.084525 | 1043519078 |335 |
| LINE | 95553328 | 199835 | 0.091568 | 1043519078 | 511 |
| LTR | 39476928 | 87021 | 0.037830 | 1043519078 | 362 |
| Other (Simple Repeat, Microsatellite, RNA) | 37933124 | 77043 | 0.036351 | 1043519078 | 112 |
| Penelope | 25187297 | 61172 | 0.024136 | 1043519078 | 112 |
| Rolling Circle | 6897773 | 17411 | 0.006610 | 1043519078 | 45 |
| SINE | 828944 | 2039 | 0.000794 | 1043519078 | 6 |
| Unclassified | 404513462 | 966499 | 0.387643 | 1043519078 | 1520 |

#### Annotating protein coding genes.

##### Processing the short read-data

First, process raw RNAseq reads with `fastp` version `0.23.4`.


```sh
cmd=(
    fastp
    --in1 ${in_dir}/${name}_R1_001.fastq.gz
    --in2 ${in_dir}/${name}_R2_001.fastq.gz
    --out1 ${out_dir}/${name}.1.fq.gz
    --out2 ${out_dir}/${name}.2.fq.gz
    --length_required 25
    --detect_adapter_for_pe
    --thread 6
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1
```

Then, align the reads to the genome using `HISAT2` version `2.2.1`. First, you need to index the assembly using `hisat2-build`.

```sh
cmd=(
    hisat2-build
    -p $thr
    $fasta
    $index
)
echo "${cmd[@]}"
"${cmd[@]}"
```

Then you can align. Important to set `--dta` in `hisat2` for compatibility with transcriptome assemblers.

```sh
# RNA seq sample lists
sams=(
    Balanus-mRNA_S1_L001
    Balanus-mRNA_S1_L002
)

# Loop over samples and process
for sam in "${sams[@]}" ; do
    echo "Working on ${sam}"
    # Prepare files
    fq1=$reads/${sam}.1.fq.gz
    fq2=$reads/${sam}.2.fq.gz
    bam=$alns/${sam}.bam
    # Align and process alignments
    hisat2 --threads $thr -x $index --dta -1 $fq1 -2 $fq2 | \
        samtools view -h -b | \
        samtools sort --threads $npr -o $bam
    # Index alns and get stats
    samtools index --threads $thr $bam
    samtools flagstat --threads $thr \
        --output-fmt tsv $bam > $alns/${sam}.stats.tsv
done
```

Use the aligned short-read RNAseq data to run `BRAKER` version `3.0.8`.

```sh
THR=16
export BRAKER_SIF=/home/ariverac/local/containers/braker3.sif

cmd=(
    # Set up singularity
    singularity exec
    # Bind all needed inputs
    --bind ${fasta}:${fasta}
    --bind ${bam}:${bam}
    --bind ${peptide}:${peptide}
    --bind ${outdir}:${PWD}
    # Specify container
    ${BRAKER_SIF}
    # Braker3 call
    braker.pl
    --genome=$fasta
    --species=balGla
    --bam=$bam
    --threads=$THR
    --prot_seq=$peptide
    --workingdir=./
    --AUGUSTUS_CONFIG_PATH=./augustus_config/
    --busco_lineage=arthropoda_odb10
    --useexisting
)
echo "${cmd[@]}"
"${cmd[@]}"
```

##### Processing the PacBio Isoseq data

We also performed an annotation with the PacBio IsoSeq data. First, we aligned this data to the genome using `minimap2` version `2.26-r1175`.

```sh
minimap2 -t ${THR} -ax splice:hq -uf $genome $reads | \
    samtools view -bS -F4 --threads ${PRC} | \
    samtools sort --threads ${PRC} -o $bam
```

Then, used the aligned IsoSeq data to run `BRAKER` v `3.0.8`. Note, these are the same commands but it is a different singularity container.

```sh
THR=16
export BRAKER_SIF=/home/ariverac/local/containers/braker3_lr.sif

cmd=(
    # Set up singularityls
    singularity exec
    # Bind all needed inputs
    --bind ${fasta}:${fasta}
    --bind ${bam}:${bam}
    --bind ${peptide}:${peptide}
    --bind ${outdir}:${PWD}
    # Specify container
    ${BRAKER_SIF}
    # Braker3 call
    braker.pl
    --genome=$fasta
    --species=balGla.IsoSeq.ArthroOdb11
    --bam=$bam
    --threads=$THR
    --prot_seq=$peptide
    --workingdir=./
    --AUGUSTUS_CONFIG_PATH=./augustus_config/
    --busco_lineage=arthropoda_odb10
    --useexisting
)
echo "${cmd[@]}"
"${cmd[@]}"
```

Lastly, merge the two annotations using `TSEBRA`.

```sh
# Run TSEBRA to combine outputs from both brakers
cmd=(
    tsebra.py
    --gtf $isoseq_braker/braker.gtf,$rnaseq_braker/braker.gtf
    --keep_gtf $rnaseq_braker/braker.gtf
    --hintfiles $isoseq_braker/hintsfile.gff,$rnaseq_braker/hintsfile.gff
    --out ${basename}.gtf
)
echo "${cmd[@]}"
"${cmd[@]}" 2> $outdir/tsebra.stderr

cmd=(
    getAnnoFastaFromJoingenes.py
    --genome $outdir/balGla.softmasked.fasta
    --gtf ${basename}.gtf
    --out $basename
)
echo "${cmd[@]}"
"${cmd[@]}" 1> $outdir/getAnnoFastaFromJoingenes.stdout 2> $outdir/getAnnoFastaFromJoingenes.stderr
```

Then, QC the final annotation using `compleasm` version `0.2.5`.

```sh
cmd=(
    compleasm
    protein
    --protein $fasta
    --lineage arthropoda_odb10
    --thr $thr
    --outdir $outd
)

# run command
echo "${cmd[@]}"
"${cmd[@]}"
```

#### Annotating non-coding transcripts

The directory `scripts/genome_annotation/non_coding` contains different script for the
annotation and processing of non-coding RNAs (e.g., rRNAs, tRNAs, lncRNAs).

##### Ribosonal RNAs

* `run_barrnap.sh`:

Annotate rRNAs using `barrnap` version `0.9`.

* `process_rrna_gff.sh`

Process the resulting rRNA annotation and standardize GFF IDs using `agat` version `1.4.3` and a custom `awk` script.

##### Transfer RNAs

* `run_tRNAscanSE.sh`

Annotate tRNAs using `tRNAscan-SE` version `2.0.12`.

* `process_trna_gff.sh`

Process the resulting tRNA annotation and standardize GFF IDs using `agat` version `1.4.3` and
a custom `awk` script.

##### Long, non-coding RNAs

* `run_minimap.sh`

Align the Pacbio IsoSeq data to the assembly using `minimap2` version `2.26-r1175`.

* `run_stringtie.sh`

Generate call _de novo_ transcripts from the IsoSeq alignments using `StringTie` version
`2.2.1`.

* `run_feelnc.sh`

Annotate lncRNAs using `FEELnc` version `0.01`. First, use `FEELnc_filter` to filter
the `StringTie` GTF to get candidate lncRNAs. Then, use `FEELnc_codpot` to compute the
coding potential score of candidate lncRNAs. Lastly, use `FEELnc_classifier` to classify
annotated lncRNAs based on their location relative to nearby genes.

* `process_lncrna_gff.sh`

Process the output lncRNA annotation using `AGAT` version `1.4.3` to standardize into
the GFF format and manage IDs.

### Comparative genomics

The `scripts/comparative_genomics/` directory contains various subdirectories describing
various comparative genomic analyses, including identifying orthologs, synteny, whole-
genome aligments, etc.

#### Identifying orthologroups

`scripts/comparative_genomics/orthofinder`:

* `run_orthofinder.sh`

Identify orthologous genes across barnacle genomes using `OrthoFinder` version `3.1.0`.

#### Conserved synteny analysis

`scripts/comparative_genomics/synteny`:

* `run_genespace.R`

Take the output from `OrthoFinder` and indentify synteny blocks using `Genespace`
version `1.3.1`. Plot the riparian plots across orthologous chromosomes.

#### Whole-genome alignment and conserved regions

`scripts/comparative_genomics/phastcons`
* `run_cactus.sh`

Run a whole genome alignment with `cactus` version `2.9.7`.

* `run_phylofit.sh`

Using the `cactus` whole-genome alignment, calculate a neutral phylogenetic model using `phyloFit` from `PHAST` version. `1.5`.

* `run_chr_phastcons.sh`

Calculate conservation scores on a `cactus` whole-genome alignment using `phastCons` from `PHAST` version `1.5`. Takes the `phyloFit` neutral model as input.

* `tally_phastcon_elements.py`:

Custom Python script that intersects the coordinates of the `phastCons` highly
conserved elements against a set of known annotated features in the genome. It
compares the proportion of the known features in the conserved elements against
their proportion in the whole genome.

Usage:

```sh
$ python3 tally_phastcon_elements.py -h

usage: tally_phastcon_elements.py [-h] -f FAI -a ANNOTATION -p PHASTCONS [-o OUT_DIR]
                                  [-m MIN_SEQ_LEN] [-i MIN_INTERVAL_LEN]

Determine the proportion of each of the annotated genetic elements in a BED across the sites
present in an phastCons conserved sites BED file. Provide other general stats for the phastCons
BED.

options:
  -h, --help            show this help message and exit
  -f, --fai FAI         (str) Path to genome index in FAI format.
  -a, --annotation ANNOTATION
                        (str) Path to the annotation in BED format.
  -p, --phastcons PHASTCONS
                        (str) Path to the phastCons conserved sited BED.
  -o, --out-dir OUT_DIR
                        (str) Path to output directory [default=.].
  -m, --min-seq-len MIN_SEQ_LEN
                        (int|float) Min length of input sequences [default=10,000].
  -i, --min-interval-len MIN_INTERVAL_LEN
                        (int) Min length of intervals in input BED files [default=1].
```

#### dN/dS analysis

`scripts/comparative_genomics/dnds`

* `extract_orthogroups_cds.py`

Custom Python script to take the orthologs from `OrthoFinder` and extract the
corresponding coding sequences for each species. It generates a per-orthogroup
FASTA containing the sequences for each species.

```sh
$ python3 extract_orthogroups_cds.py -h

usage: extract_orthogroups_cds.py [-h] -s SCO_LIST -r ORTHOGROUPS_TSV
                                  -c CDS_IN_DIR [-o OUT_DIR] [-t] [-f]

options:
  -h, --help            show this help message and exit
  -s, --sco-list SCO_LIST
                        (str) Path to orthofinder
                        Orthogroups/Orthogroups_SingleCopyOrthologues.txt file.
  -r, --orthogroups-tsv ORTHOGROUPS_TSV
                        (str) Path to the orthofinder
                        Orthogroups/Orthogroups.tsv
  -c, --cds-in-dir CDS_IN_DIR
                        (str) Path to the directory containing the input per-
                        taxon CDS sequences.
  -o, --out-dir OUT_DIR
                        (str) Path to output directory [default=./].
  -t, --trim-stops      Trim the 3' stop codons from the extracted sequences
                        [default=False]
  -f, --check-frame     Filter out sequences if the codons are out of frame,
                        not multiple of 3 [default=False]
```

* `run_prank_msa.sh`

Generate a codon-aware multiple sequence alignment using `prank` version `v.170427`.

* `run_clipkit.sh`

Filter and trim multiple sequence alignments using `ClipKIT` version `2.7.0`.

* `pairwise_dnds.py`

Custom Python script used to process pairwise alignments of coding sequences and
calculate dN/dS. It depends on the [`dnds`](https://github.com/adelq/dnds) and
[`BioPython`](https://biopython.org) packages.

```sh
$ python3 pairwise_dnds.py -h

usage: pairwise_dnds.py [-h] -s SCO_LIST -a ALIGNMENTS -i INGROUP
                        [-o OUT_DIR] [-m MIN_ALN_LEN] [-p ALN_SUFFIX]

options:
  -h, --help            show this help message and exit
  -s SCO_LIST, --sco-list SCO_LIST
                        (str) Path to the single-copy orthgroup table
                        (produced by `extract_orthogroups_cds.py`).
  -a ALIGNMENTS, --alignments ALIGNMENTS
                        (str) Path to the directory with the trimmed
                        multiple sequence alignments.
  -i INGROUP, --ingroup INGROUP
                        (str) ID of the ingroup (focal) species in the
                        alignment. Used to report gene/transcript IDs
                        in the output.
  -o OUT_DIR, --out-dir OUT_DIR
                        (str) Path to output directory [default=./].
  -m MIN_ALN_LEN, --min-aln-len MIN_ALN_LEN
                        (int) Minimum length required to keep an alignment
                        [default=25]
  -p ALN_SUFFIX, --aln-suffix ALN_SUFFIX
                        (str) Suffix for the alignment FASTA files
                        [default=fa].
```

#### McDonald-Kreitman test

`scripts/comparative_genomics/mk_test`

* `extract_hap_cds.py`

Custom Python scripts that takes the genetic variants in a VCF file and propagates
these variants along genomic regions specified in a GFF file. It can be used to
generate per-sample, per-haplotype consensus sequences for protein coding genes.
It generates *n* consensus files per sample in the VCF, where *n* is the ploidy.
It depends on `bcftools` and `samtools`.

```sh
$ python3 extract_hap_cds.py -h

usage: extract_hap_cds.py [-h] -g GENOME -f GFF -v VCF [-o OUT_DIR]
                          [-t THREADS] [--snps-only]

options:
  -h, --help            show this help message and exit
  -g GENOME, --genome GENOME
                        (str) Path to genome in FASTA format.
  -f GFF, --gff GFF     (str) Path to the annotation in GFF format.
  -v VCF, --vcf VCF     (str) Path to variants in VCF/BCF format.
  -o OUT_DIR, --out-dir OUT_DIR
                        (str) Path to output directory [default=.].
  -t THREADS, --threads THREADS
                        (int) Number of threads to run in parallel sections
                        of code [default=1].
  --snps-only           Filter the input variants to only keep SNPs.
  ```

* `run_mkado.sh`

Calculate three different versions of the McDonald-Kreitman test using the
`MKado` version `0.2.0` software:

1. Standard MK test (McDonald & Kreitman 1991)
2. Asymptotic MK test (Messer & Petrov 2013)
3. Tarone-Greenland estimator (Stoletzki and Eyre-Walker, 2011)

#### Codon usage biases

`scripts/comparative_genomics/codon_usage`

* `run_cubar.sh`

Take a set of coding sequences in FASTA format and calculate codon
usage using the `cubar` version `1.2.0` R package. The script does a
few statistics, but the main one we care about here is the effective
number of codons (ENC).

### Reference sample popgen

The directory `popgen/reference_sample` contains a series of scripts for
calculating diversity statistics on the *B. glandula* refererence individual,
including aligning reads, genotyping, and filtering.

* `mmp_align_hifi.sh`

Align the processed PacBio HiFi reads using `minimap2` version `2.28-r1209`.
Process the resulting alignments with `samtools` version `1.21`. Calculate
depth of coverage using `mosdepth` version `0.3.10`.

* `run_bcftools_hifi.sh`

Use `BCFtools` version `1.21` `mpileup` and `call` to genotype the barnacle reference
individual. Run the genotyping per-chromosome.

* `run_bcftools_norm.sh`

Normalize indels and adjacent variant sites using `BCFtools norm`.

* `softFilt_bcf.sh`

Filter the variants using `BCFtools filter` and `view`.

* `run_snpEff.sh`

Take the set of called variants and annotate their effects using `snpEff` version `5.2`.
First, the script builds a `snpEff` database. Then, it annotates the VCF.

### Oregon barnacle popgen

The directory `/scripts/popgen` contains various script for analyzing the population
genetics data for central Oregon barnacles. This includes the alignment and genotyping
of individuals as well as various downstream analyses.

## *Balanus crenatus* genome assembly and annotation

* The wrinkled barnacle (*Balanus crenatus*).
* NCBI TaxID: [164412](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=164412)

### Sample information and sequencing

#### PacBio HiFi

Sample is one of four individuals collected on Nov 2023 by Erin Jezuit at the Oregon Institute of Marine Biology, Charleston OR ([map](https://maps.app.goo.gl/8bmcutaaJussMBcy5)).

DNA was extracted with PacBio Nanobind and sequenced on two runs of PacBio HiFi at the University of Oregon's GC3F.

Path to raw data:

```
/sietch_colab/data_share/balanus/balanus_crenatus/hifi_reads
```

### Genome assembly

#### K-mer estimation

TODO: Redo in the pooled data.

#### Contig-level assembly

Generated a contig-level assembly using `hifiasm` version `0.19.8-r603`. This run contained strict parameter for the identification and purging of haplotig sequences.

```sh
cmd=(
    hifiasm
    -o $name
    --hom-cov 40
    -t 24
    -s 0.25
    --hg-size 800m
    --dual-scaf
    --purge-max 40
    -D 10.0
    -l 3
    $reads/m64047_240125_175314.ccs.fastq.gz
    $reads/m64047_240127_045016.ccs.fastq.gz
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1

# Convert the GFA to fasta
cat ${name}.bp.p_ctg.gfa | awk '/^S/{print ">"$2;print $3}' | \
    gzip > ${name}.p_ctg.fasta.gz
```

This assembly is composed of 2,932 contigs, a total length of 1.20 Gbp,largest contig of 3.51 Mbp, and a contig N50 of 746 Kbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237`, `C` = 94.96%, `D` = 19.64%.

```
## lineage: arthropoda_odb10
S:75.32%, 763
D:19.64%, 199
F:0.89%, 9
I:0.00%, 0
M:4.15%, 42
N:1013
```

### Filtering contamination

Filtering contamination by running `mmseqs2` version `X.XX`.

<!--- TODO --->
see:

```
/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/mmseqs2
```

After finishing taxonomical assignment, we only selected sequences matching the target NCBI taxonomical ID (Thecostraca: [116172](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=116172&lvl=3&lin=f&keep=1&srchmode=1&unlock)).

```sh
# Input FASTA (must be indexed)
in_fasta=$work/in_genome/balCre.hmc40_D10_s25.p_ctg.fasta

# Taxonomy output table from MMSeqs2
tsv=$work/balCre_tax.tsv

# NCBI taxonomy category for checking
tax=116172 # Thecostraca

# Filter the contig IDs in TSV to only include those matching the target ID
matches=$work/${tax}_ctgs.tsv
cat $tsv | grep "\b${tax}\b" | cut -f1 | sort -u > $matches

# Select the subset of matching sequences from the FASTA
out_fasta=$work/out_genome/balCre_${tax}_ctgs.fasta
samtools faidx --region-file $matches $in_fasta | \
    fold -w 60 > $out_fasta

# Index the resulting genome
samtools faidx $out_genome
```

Note: There might be other ways to do this straight from `mmseqs2`.

#### Check the post-cleanup genome

This assembly is composed of 2,696 contigs, a total length of 1.18 Gbp,largest contig of 3.51 Mbp, and a contig N50 of 758.4 Kbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237`,  `C` = 94.57%, `D` = 19.45%.

```sh
## lineage: arthropoda_odb10
S:75.12%, 761
D:19.45%, 197
F:0.89%, 9
I:0.00%, 0
M:4.54%, 46
N:1013
```

### Purging haplotig sequences

We purges haplotig sequences using `purge_dups` version `1.2.5`.

First, aligned the PacBio HiFi to the genome and did the assembly self-alignment using `minimap2` version `2.26-r1175`.

```sh
# Align the reads to the reference
minimap2 -x map-hifi -t 16 $genome $reads | gzip -c - > $paf

# Calculate read-depth histogram
pbcstat -O $alns_out $paf

# Calculate base-level depth
calcuts PB.stat > cutoffs 2>calcults.log

# Do an assembly self-alignment
split_fa $genome > $split
minimap2 -x asm20 -t 16 -DP $split $split | gzip -c - > $self
```

We then tan `purge_dups` and the `get_seqs` utility to identify and filter haplotig sequences.

```sh
# Mark the duplicates in a bed file
cmd=(
    purge_dups
    -2
    -T $alns/cutoffs
    -c $alns/PB.base.cov
    $paf
)
echo "${cmd[@]}"
"${cmd[@]}" > dups.bed 2> purge_dups.log

# Process the assembly
cmd=(
    get_seqs
    -e
    -s
    -p $name
    dups.bed
    $geno
)
echo "${cmd[@]}"
"${cmd[@]}" > get_seqs.log 2>&1
```

#### Post-Purge Dups stats

This assembly is composed of 1,548 contigs, a total length of 907.4 Mbp,largest contig of 3.51 Mbp, and a contig N50 of 925.5 Kbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237`,  `C` = 93.39%, `D` = 3.16%.

```sh
## lineage: arthropoda_odb10
S:90.23%, 914
D:3.16%, 32
F:0.89%, 9
I:0.00%, 0
M:5.73%, 58
N:1013
```

In comparison with the un-purged assembly:

* Number of contigs went from 2.9 K to 1.5 K
* Total length went from 1.20 Gbp to 907 Mbp
* Contig N50 went from 746 Mbp to 1.31 Mbp
* BUSCO C went from 94.96% to 93.39%
* BUSCO D went from 19.64% to 3.16%

### Correct sequences

We performed one additional round of curation using `inspector` version `1.0.1`.

```sh
# Inspector evaluate
cmd=(
    inspector.py
    --contig $fasta
    --read $hifi
    --thread $thr
    --outpath $outdir
    --datatype "hifi"
)
echo "${cmd[@]}"
"${cmd[@]}"

# Inspector correct
cmd=(
    inspector-correct.py
    --inspector $outdir
    --outpath $cordir
    --datatype "pacbio-hifi"
    --thread $thr
)
echo "${cmd[@]}"
"${cmd[@]}"
```

#### Post-Inspector stats


This assembly is composed of 1,548 contigs, a total length of 907.3 Mbp,largest contig of 3.51 Mbp, and a contig N50 of 925.6 Kbp (checked with `quast` version `5.2.0`).

We verified gene-completeness using `compleasm` version `0.12-r237`,  `C` = 93.39%, `D` = 3.26%.

```sh
## lineage: arthropoda_odb10
S:90.13%, 913
D:3.26%, 33
F:0.89%, 9
I:0.00%, 0
M:5.73%, 58
N:1013
```

In comparison with the un-purged assembly:

* Number of contigs stayed the same
* Total length went from 907.4 Mbp to 907.3 Mbp
* Contig N50 went from 925.5 Kbp to 925.6 Kbp
* BUSCO C stayed the same
* BUSCO D went from 3.16% to 3.26%

* Reference-guided scaffolding

## *Balanus nubilis* genome assembly and annotation

* The giant acorn barnacle (*Balanus nubilis*).
* NCBI TaxID: [6678](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=6678)

<!--- TODO --->

## Other genome assemblies

See:

```
/sietch_colab/data_share/balanus/crustacean_outgroup_assemblies
```

All the ones downloaded:

| Spp name | Class | Family | Spp Code | NCBI Accession | Assembly ID | In OrthoDB v11<sup>1</sup> | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | 
| *Amphibalanus amphitrite* | Thecostraca | Balanidae | `AmpAmp` | `GCF_019059575.1` | NRLGWU_Aamphi_draft | yes | -- |
| *Amphibalanus amphitrite* | Thecostraca | Balanidae | `AmpAmp` | `GCA_037642225.1` | ASM3764222v1 | no | Annotation from Han et al. 2024<sup>2</sup> |
| *Artemia franciscana* | Branchiopoda | Artemiidae | `ArtFra` | `GCF_032884065.1` | ASM3288406v1 | no | -- |
| *Capitulum mitella* | Thecostraca | Pollicipedidae | `CapMit` | `GCA_030062745.1` | ASM3006274v1 | no | No annotation |
| *Cherax quadricarinatus* | Malacostraca | Parastacidae | `CheQua` | `GCF_026875155.1` | ASM2687515v2 | no | -- |
| *Daphnia magna* | Branchiopoda | Daphniidae | `DapMag` | `GCF_020631705.1` | ASM2063170v1.1 | yes | -- |
| *Daphnia pulicaria* | Branchiopoda | Daphniidae | `DapPui` | `GCF_021234035.1` | SC_F0-13Bv2  | yes | -- |
| *Daphania pulex* | Branchiopoda | Daphniidae | `DapPul` | `GCF_021134715.1` | ASM2113471v1 | yes | -- |
| *Eriocheir sinensis* | Malacostraca | Varunidae | `EriSin` | `GCF_024679095.1` | ASM2467909v1 | no | -- |
| *Eurytemora carolleeae/affinis* | Hexanauplia/Copepoda | Temoridae | `EurAff` | `GCF_000591075.1` | Eaff_2.0 | yes | -- |
| *Homarus americanus* | Malacostraca | Nephropidae | `HomAme` | `GCF_018991925.1` | GMGI_Hamer_2.0 | yes | -- |
| *Hyalella azteca* | Malacostraca | Hyalellidae | `HyaAzt` | `GCF_000764305.2` | Hazt_2.0.2 |  yes | -- |
| *Lepeophtheirus salmonis* | Hexanauplia/Copepoda | Caligidae | `LepSal` | `GCF_016086655.3` | UVic_Lsal_1.2 | yes | -- |
| *Macrobrachium rosenbergii* | Malacostraca | Palaemonidae | `MacRos` | `GCF_040412425.1` | ASM4041242v1 | no | -- |
| *Penaeus chinensis* | Malacostraca | Penaeidae | `PenChi` | `GCF_019202785.1` | ASM1920278v2 | yes | -- |
| *Penaeus japonicus* | Malacostraca | Penaeidae | `PenJap` | `GCF_017312705.1` | Mj_TUMSAT_v1.0 | yes | -- |
| *Penaeus monodon* | Malacostraca | Penaeidae | `PenMon` | `GCF_015228065.2` | NSTDA_Pmon_1 | yes | -- |
| *Penaeus vannamei* | Malacostraca | Penaeidae | `PenVan` | `GCF_019202785.1` | ASM1920278v2 | yes | -- |
| *Pollicipes pollicipes* | Thecostraca |  Pollicipedidae | `PolPol` | `GCF_011947565.3` | Ppol_2.1 | yes | -- |
| *Portunus trituberculatus* | Malacostraca | Portunidae |  `PorTri` | `GCF_017591435.1` | ASM1759143v1 | yes | -- |
| *Procambarus clarkii* | Malacostraca | Cambaridae | `ProCla` | `GCF_020424385.1` | ASM2042438v2 | yes | -- |
| *Sacculina carcini* | Thecostraca | Sacculinidae | `SacCar` | `GCA_916048095.2` | qxSacCarc1.2 | no | No annotation |
| *Scylla paramamosain*  | Malacostraca | Portunidae | `ScyPar` | `GCF_035594125.1` | ASM3559412v1 | no | -- |
| *Tigriopus californicus* | Hexanauplia/Copepoda | Harpacticidae | `TigCal` | `GCF_007210705.1` | Tcal_SD_v2.1 | yes | -- |


<sup>1</sup>Crustacean species in OrthoDB v11 ([link](https://www.orthodb.org/?level=6657&species=6657)). See:

```
/sietch_colab/ariverac/balanus_genome/ncbi_data/orthodb_v11_Crustacea
```

<sup>2</sup>*A. amphitrite* assembly by Han et al. 2024:

>Han, Z., Wang, Z., Rittschof, D. et al. New genes helped acorn barnacles adapt to a sessile lifestyle. *Nat Genet 56*, 970-981 (2024). <https://doi.org/10.1038/s41588-024-01733-7>

Assembly is on NCBI ([link](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_037642225.1/)), annotation is provided by the authors on Figshare ([link](https://doi.org/10.6084/m9.figshare.21310305)).

<!--- TODO --->


## Comparative analysis
<!--- TODO --->

Add `orthofinder` code info.

For downstream processing, Generating the counts table using

```sh
$ orthogroup_gene_count.py Phylogenetic_Hierarchical_Orthogroups/N0.tsv
```

This is described in the orthofinder issues
([link](https://github.com/davidemms/OrthoFinder/issues/511)).

## Popgen analysis
<!--- TODO --->

## Authors

**Angel G. Rivera-Colon**  
Institute of Ecology and Evolution  
University of Oregon

**Scott Small**  
Institute of Ecology and Evolution  
University of Oregon

**Andrew Kern**  
Department of Biology  
Institute of Ecology and Evolution  
University of Oregon
