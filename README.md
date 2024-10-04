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
Continue in:
```
/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff
```

* Hi-C scaffolding
* Tigmint checks
* re-scaffolding
* re-Purge Dups
* inspector

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

We verified gene-completeness using `compleasm` version `0.12-r237`. Duplicates went at ~20%.

```
## lineage: arthropoda_odb10
S:75.32%, 763
D:19.64%, 199
F:0.89%, 9
I:0.00%, 0
M:4.15%, 42
N:1013
```

<!--- TODO --->
* MMseqs2
* Purge Dups
* Reference-guided scaffolding
* inspector

## *Balanus nubilis* genome assembly and annotation

* The giant acorn barnacle (*Balanus nubilis*).
* NCBI TaxID: [6678](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=6678)

<!--- TODO --->

## Other genome assemblies

See:

```
/sietch_colab/ariverac/balanus_genome/ncbi_data/orthodb_v11_Crustacea
```
<!--- TODO --->


## Comparative analysis
<!--- TODO --->

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
