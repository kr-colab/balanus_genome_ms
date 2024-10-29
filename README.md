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

One of several individuals collected on August 2024 by the Kern-Ralph co-lab at Cape Perpetua, OR ([map](https://maps.app.goo.gl/NjL9mCNNjerpXvnY7)).

<!--- Cape Perpetua or Bob Creek? --->

Tissue was processed by Phase Genomics into a Hi-C library and 2x150bp sequenced on an Illumina NovaSeq 6000 at the University of Oregon's GC3F.

Path to raw data:

```
/sietch_colab/data_share/balanus/hi-c/7549
```

#### RNAseq & Iso-Seq

One of several individuals collected on August 2024 by the Kern-Ralph co-lab at Cape Perpetua, OR ([map](https://maps.app.goo.gl/NjL9mCNNjerpXvnY7)).

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

#### TELLseq

One of several individuals collected on August 2024 by the Kern-Ralph co-lab at Bob Creek, OR ([map](https://maps.app.goo.gl/Kzq9TssYcpcbbqvP6)). More TELLseq was performed on other individuals for collecting popgen data.

DNA was extracted using PacBio Nanobind and prepared in a TELLseq library. Sequenced 2x150bp on an Illumina NovaSeq 6000 at the University of Oregon's GC3F.

<!--- Confirm this --->

Path to raw reads:

```
/sietch_colab/data_share/balanus/tellseq_analysis/illumina_raw_reads/merged_reads_7698_7699
```

Note: Sample used for the scaffolding was `Bgland_1`

### Genome assembly

#### K-mer estimation

TODO: Ask @Andy for the originail results or redo in the pooled data.

#### Initial contig-level assembly

The raw HiFi reads were assemblied using `hifiasm` version `0.19.6-r595` using defeault parameters.

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

### Missasembly correction

#### Tigmint

<!--- Check details with @Scott --->

We used `tigmint` version `X.XX` using TELLseq data to generate "breaktigs" represening the split of missasembled regions.

```sh
# TODO: Add tigmint stuff here
```

#### Re-scaffolding

We extracted all breaktigs larger than 10 Kbp into a new FASTA (267 fragments total).

The total size of this portion is 933.16 Mbp. The gene-completeness of these breaktigs is (BUSCO C = 92.01%):

```sh
## lineage: arthropoda_odb10
S:88.06%, 892
D:3.95%, 40
F:1.28%, 13
I:0.00%, 0
M:6.71%, 68
N:1013
```

These were re-scaffolded with Hi-C reads using the same process as before (`bwa` -> `samtools` -> `pairtools` -> `yahs` -> `juicer`).

This resulted in:

Checked with `quast` version `5.2.0`

| statistic | value |
| --------- | ----- |
| Total size | 933.1 Mbp |
| # scaffolds | 176 |
| # contigs | 1,555 |
| Largest scaffold | 128.5 Mbp |
| Scaffold N50 | 59.2 Mbp |
| Contig N50 | 1.22 Mbp |
| Scaffold L50 | 6 |
| Total len > 1 Mbp | 915.8 Mbp |
| Fragments > 1 Mbp | 46 |
| % leb >  1 Mbp | 98.1% |
| Total len > 10 Mbp | 850.5 Mbp |
| Fragments > 10 Mbp | 14 |
| % len >  10 Mbp | 91.1% |

We verified gene-completeness using `compleasm` version `0.12-r237` (92.20% complete).

```
## lineage: arthropoda_odb10
S:88.55%, 897
D:3.65%, 37
F:1.09%, 11
I:0.00%, 0
M:6.71%, 68
N:1013
```

#### Curating Hi-C re-scaffolding

Did some manual correction using `juicebox` version `2.17.00`, primarily doing large-scale changes. Resulting in:

Checked with `quast` version `5.2.0`

| statistic | value |
| --------- | ----- |
| Total size | 933.2 Mbp |
| # scaffolds | 237 |
| # contigs | 1,643 |
| Largest scaffold | 80.2 Mbp |
| Scaffold N50 | 50.96 Mbp |
| Contig N50 | 1.17 Mbp |
| Scaffold L50 | 8 |
| Total len > 1 Mbp | 896.2 Mbp |
| Fragments > 1 Mbp | 50 |
| % leb >  1 Mbp | 96.3% |
| Total len > 10 Mbp | 832.6 Mbp |
| Fragments > 10 Mbp | 15 |
| % len >  10 Mbp | 89.2% |

We verified gene-completeness using `compleasm` version `0.12-r237` (91.9% complete.)

```
## lineage: arthropoda_odb10
S:88.15%, 893
D:3.75%, 38
F:1.28%, 13
I:0.00%, 0
M:6.81%, 69
N:1013
```

In comparison before the manual curation:

* Number of fragments went from 176 to 237
* Total length remained the same
* Largest fragment went from 128.5 Mbp to 80.2 Mbp
* BUSCO C went from 92.2% to 91.9%
* BUSCO D went from 4.84% to 3.75%.

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
| Total size | 929.2 Mbp |
| # scaffolds | 233 |
| # contigs | 1,575 |
| Largest scaffold | 80.3 Mbp |
| Scaffold N50 | 52.86 Mbp |
| Contig N50 | 1.22 Mbp |
| Scaffold L50 | 8 |
| Total len > 1 Mbp | 892.2 Mbp |
| Fragments > 1 Mbp | 50 |
| % leb >  1 Mbp | 96.0% |
| Total len > 10 Mbp | 828.7 Mbp |
| Fragments > 10 Mbp | 15 |
| % len >  10 Mbp | 89.2% |

We verified gene-completeness using `compleasm` version `0.12-r237` (91.41 % complete.)

```ls
## lineage: arthropoda_odb10
S:87.66%, 888
D:3.75%, 38
F:1.38%, 14
I:0.00%, 0
M:7.21%, 73
N:1013
```

In comparison before `inspector` correction:

* Number of fragments went from 237 to 233
* Total length decreased by ~4 Mbp
* Largest fragment went from 80.2 to  80.3 Mbp
* BUSCO C went from 91.9% to 91.4.
* BUSCO D remained at 3.75%.

### Genome annotation
<!--- TODO --->

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

* Reference-guided scaffolding
* inspector

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
