# Bioinformatic materials and methods

This `scripts/` directory contains a file-by-file description of the bioinformatics
scripts used in the manuscript. It describes the genome assembly and annotation of the
Pacific acorn barnacle (*Balanus glandula*), comparative genomic analyses with other
barnacle outgroup species, and population genetic analysis of a barnacle population
from the central Oregon coast. This file additionally contains the accession information
for the publicly available data generated for this project and/or used during the analyses.

## *Balanus glandula* genome assembly and annotation

* The Pacfic acorn barnacle (*Balanus glandula*).
* NCBI TaxID: [110520](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=110520)

### Sample information and sequencing

Raw data available on NCBI BioProject
[PRJNA1378260](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA1378260).

| Sequencing | Location | Date Collected | NCBI BioSample |
| - | - | - | - |
| PacBio HiFi | Oregon Institute of Marine Biology, Charleston, OR, USA | Feb 2023 | SAMN56729174 |
| Oxford Nanopore ONT | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729176 |
| Hi-C | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729175 |
| RNAseq+IsoSeq | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729177 |

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

The directory `scripts/genome_assembly/def_contigs` contains scripts for the
base assembly of contigs.

* `run_hifiasm_default.sh`

Assemble the raw HiFi reads with `hifiasm` version `0.19.6-r595` using
default parameters.

* `run_quast.sh`

Assess contiguity of the assembly using `quast` version `5.2.0`.

* `run_compleasm.sh`

Assess gene-completeness of the assembly using `compleasm` version `0.12-r237`,
comparing against the `arthropoda_odb10` `BUSCO` dataset.

### Filtering for contamination

The directory `scripts/genome_assembly/contamination` contains script for
detecting and removing contaminant sequences in the assembly.

#### Initializing database

* `run_blobtools_create.sh`

This script initializes a new `BlobTools` database for the genome assembly. It uses
`blobtoolkit` version `4.3.0` and specifies the NCBI taxonomic ID as `110520` (entry
for *B. glandula*).

#### Adding coverage data

Adding per-contig coverage estimates.

* `run_minimap_hifi_aln.sh`

This script aligns the raw PacBio HiFi reads to the contig-level assembly using
`minimap2` version `2.26-r1175`.

* `run_blobtools_add_cov.sh`

Determine the depth of coverage from the aligned reads and add the coverage estimates
to the database using `blobtools add`.

To assign taxonomy, we queried the contig-level assembly against NCBI's `nt` database
(downloaded on 2023-12-13).

#### Adding taxonomic information

Assign a taxonomic assignment to each assembled contig.

* `run_blastn.sh`

Use `blastn` version `2.15.0+` to map the assembled contigs against NCBI's `nr`
database (downloaded on 2023/12/13).

* `run_blobtools_add_hits.sh`

Add the `BLAST` results to the `BlobTools` database using `blobtools add`.
Use the `bestsumorder` taxonomic rule to do the taxonomic assignment for each contig.

#### Filter contaminant sequences

Using the assigned taxonomy, filter to obtain all contigs, as well as and the
associated reads aligned to those contigs, that match to the class Thecostraca.

* `run_blobtools_filter.sh`

Export the contig and read IDs of all sequences assigned to the class Thecostraca
using `blobtools filter`. Use the `bestsumorder` taxonomic rule. In other words,
this commands filters out anything that is not assigned to barnacles.

* `run_seqtk.sh`

Use `seqtk` version `1.4-r130-dirty` to subset the raw HiFi to retain only those
assigned to Thecostraca.

This processes, estimating coverage, assigning taxonomy, and filtering using
`blobtools`, was also repeated for the ONT reads.

### Optimized contig-level assembly

The directory `scripts/genome_assembly/opt_contigs` contains scripts for 
processing and analysing the optimized contig-level assembly.

#### Assemble contigs

* `run_hifiasm_optimized.sh`

Assemble the filtered, Thecostraca-specific reads using `hifiasm` version
`0.19.8-r603`. This run included both ONT and Hi-C data, and has more strict
parameters for the purging of haplotig sequences.

#### Purging haplotig sequences

* `run_pd_mininap.sh`

This scripts aligns the reads back to the genome and calculate some
coverage statistics.

1. Align the filtered reads to the optimized contig-level
assembly using `minimap2` version `2.26-r1175`.
2. Use `pbcstat` tool from `purge_dups` version `1.2.5` to
calculate the read-depth histogram.
3. Use `calcuts` tool from `purge_dups` version `1.2.5` to
calculate the base-level depth coverage cutoffs.
4. Split the genome for self alignment using `split_fa`.
5. Do the self alignment of the genome with `minimap2` version
`2.26-r1175`.

* `run_purge_dups.sh`

This script removes haplotig sequences from the assembly in the following
steps:

1. Use `purge_dups` version `1.2.5` to mark the duplicate sequences in
a BED file.
2. Process the assembly to extract the haplotig sequences using `get_seqs`.

### Hi-C scaffolding

The directory `scripts/genome_assembly/hic_scaffolds` contains scripts
for the scaffolding of the genome using Hi-C reads.

* `run_hic_alns.sh`

This script aligns the Hi-C reads to the genome using `bwa mem` version
`0.7.17-r1188`. Reads are then processed with `pairtools` version `1.0.2`
in order to:

1) Record valid ligation events (`pairtools parse`)
2) Sorting the pairs (`pairtools sort`)
3) Remove PCR duplicates (`pairtools dedup`)
4) Splitting into corresponding aligment and read pairs file (`pairtools split`)

The alignment and processing of Hi-C read pairs was done following the Omni-C
pipeline ([link](https://omni-c.readthedocs.io/en/latest/fastq_to_bam.html)),
in accordance to the `yahs` documentation.

#### Scaffolding the genome

* `run_yahs.sh`

Take the processed alignments and gene `yahs` version `1.2a.1` to scaffold
the contigs into chromosome-level scaffolds.

#### Generating contact map

* `run_juicer.sh`

Following the `yahs` documentation, generate a contact map from the Hi-C
data using `juicer pre` version `1.1` and `juicer tools` version `1.9.9`.
The scripts also generates an `*.assembly` files, which can be edited using
`juicebox`.

#### Manual curation of the contact map

Did some manual correction using `juicebox` version `2.17.00`, primarily doing large-scale changes.

* `run_juicer_post.sh`

Re-generate the assembly after manual curation using `juicer post` version
`1.1`.

#### Correct the assembly

* `run_inspector.sh`

Perform a round of self-correction in the assembly using `inspector` version
`1.0.1`. This scripts first runs `inspector.py` to align the reads and 
evaluate the assembly, and then it corrects any errors using
`inspector-correct.py`.

#### Sorting and renaming sequences

* `rename_sort_fa.py`

Custom Python script to sort and rename the sequences in the genome. Here,
we sorted the sequences by length and renamed them accordingly. Sequences
larger than 10 Mb were assigned as chromosomes.

```sh
$ python3 rename_sort_fa.py -h
usage: rename_sort_fa.py [-h] -f IN_FASTA -i IN_FAI [-k NAME_KEY]
                         [-o OUT_DIR] [-b BASENAME] [-m MIN_CHR_LEN]
                         [-g GTF] [-l MIN_SEQ_LEN] [--rename-by-length]
                         [--export-sorted]

Process an input FASTA along with annotations to rename the sequences
and sort the output.

options:
  -h, --help            show this help message and exit
  -f IN_FASTA, --in-fasta IN_FASTA
                        (str) Path to input FASTA.
  -i IN_FAI, --in-fai IN_FAI
                        (str) Path to input FASTA index (FAI).
  -k NAME_KEY, --name-key NAME_KEY
                        (str) Path to name key file.
  -o OUT_DIR, --out-dir OUT_DIR
                        (str) Output directory.
  -b BASENAME, --basename BASENAME
                        (str) Name of current run. Defaults to datetime.
  -m MIN_CHR_LEN, --min-chr-len MIN_CHR_LEN
                        (int/float) Minimum length of sequence to label
                        as a chromosome. [default = 1,000,000]
  -g GTF, --gtf GTF     (str) Path to input GTF/GFF3.
  -l MIN_SEQ_LEN, --min-seq-len MIN_SEQ_LEN
                        (int/float) minimum length needed to export a
                        sequence. [default = 1,000]
  --rename-by-length    Rename the chromosome sequences by their length
                        in BP (i.e., longest sequences is chromosome 1).
  --export-sorted       Export the sequences sorted by size. Defaults to
                        the order of sequences in the FAI.
```

### Genome annotation

#### Repeat annotation

The directory `scripts/genome_annotation/repeats` contains several scripts for the
identification and annotation of repeats.

* `extract_dfam38.sh`

Extract the repeat sequences for Crustacea (NCBI taxid `6657`) from the `Dfam 3.8`
database.

* `run_earlGrey.sh`

Annotate repeats using `EarlGrey` version `4.0.1`. We are using the `Dfam 3.8`
Crustacean repeat sequences as the starting consensus library for an initial mask,
and using "`arthropoda`" as the initial search term for `RepeatMasker` version
`4.1.2`.

#### Annotating protein coding genes.

The directory `scripts/genome_annotation/braker` contains various scripts for
running the genome annotation using `BRAKER`. It contains script for the annotation
woth both short-read RNAseq data and long-read PacBio IsoSeq.

##### RNAseq-based annotation

* `run_fastp.sh`

Process the raw RNAseq reads with `fastp` version `0.23.4`.

* `run_histat_idx.sh`

Index the *B. glandula* reference assembly using the `hisat2-build` command from
`HISAT2` version `2.2.1`.

* `run_histat_aln.sh`

Align the processed RNAseq reads using `hisat2`. Important to set `--dta` in `hisat2`
for compatibility with transcriptome assemblers. The resulting alignments are processed
and sorted using `samtools`. Since there are two RNAseq lanes, this command is run
separately for each lane.

* `run_merge_bams.sh`

Merge the alignment of the two RNAseq into a single BAM files. This final BAM file
is also filtered and processed using `samtools`.

* `run_braker3_container.sh` 

Use the `BRAKER` version `3.0.8` container to annotate the genome using the processed
short-read alignments.

##### IsoSeq-based annotation

* `run_mmap_isoseq_aln.sh`

Align the PacBio IsoSeq data to the barnacle reference genome using `minimap2` version
`2.26-r1175`, with the `-x splice:hq` command. Process and sort the alignments using
`samtools`.

* `run_braker3_lr_container.sh`

Use the `BRAKER` version `3.0.8` long-read branch container to annotate the genome
using the processed IsoSeq long-read alignments. Note, these are the same commands as
the ones used for the short-read version, but it is a different singularity container
specific for the `BRAKER` long-read development branch.

##### Merging the short- and long-read BRAKER annotations

* `rerun_tsebra.sh`

Re-run the `TSEBRA` command from `BRAKER` version `3.0.8` to merge the short-read
and long-read annotations. 

* `run_compleasm.sh`

Assess the gene-completeness of the annotated transcriptiome using the `protein`
command from `compleasm` version `0.2.5` against the `arthropoda_odb10` reference set.

#### Transcript and isoform curation

##### Isoform QC

The directory `scripts/genome_annotation/sqanti` contains scripts to run the `SQANTI3` version
`5.2.2` pipeline. It takes a set of assembled transcripts and performs QC on the isoforms.

* `run_sqanti_qc.sh`

Perform QC on the isoforms by comparing against the RNAseq short reads and the reference
annotation.

* `run_sqanti_filter.sh`

Filter the transcripts based on their QC. We are using the default rules except for retaining
mono-exonic transcripts.

* `run_sqanti_rescue.sh`

Attempt to rescue transcripts and isoforms filtered by the `SQANTI3` QC process.

##### Find protein-coding transcripts

The directory `scripts/genome_annotation/transdecoder` contains scripts for identifying
protein-coding transcripts among the curated `SQANTI` isoforms.

* `transdecoder_preprocessing.sh`

Preprocess the annotation by extracting the protein and coding sequences for annotated
transcripts and isoforms. It then extract the representative longest open reading frames
using `TransDecoder.LongOrfs` for future processing.

* `transdecoder_homology.sh`

Takes the extracted coding sequences and finds homology using `hmmsearch` version `3.4` and
`blastp` version `2.15.0+`.

* `transdecoder_predict.sh`

It does the final coding prediction of the putative transcripts by incorporating the homology
results. The resulting coding transcripts are mapped back to the genome and merged with the different isoforms. Non-coding transcripts and/or isoforms lacking homology hits are removed.

##### Merging the isoform and reference annotations

The directory `scripts/genome_annotation/taco` has scripts for merging the isoform and
reference annotations using `tacoRNA` version `0.7.3`.

* `run_tacoRNA.sh`

Use `taco_run` to identify overlaps between the two annotations, the isoform annotation from
`SQANTI3`+`TransDecoder` and the "reference" annotation from `BRAKER`.

* `run_taco_refcomp.sh`

Compared the merged annotation against the reference genome to ensure the proper merging of
transcripts and isoforms.

##### Processing the output annotation

The directory `scripts/genome_annotation/agat` contains scripts for processing the final
annotation (GFF, CDS FASTA, and protein FASTA) using `AGAT` version `1.4.3`.

* `gfff_clean.sh`

Processes the annotation using several `AGAT` utilities:

1. Initial processing and filtering with `agat_convert_sp_gxf2gxf.pl`. Makes all the IDs and 
   parent/offspring features consistent.
2. Select the longest isoform (`agat_sp_keep_longest_isoform.pl`).
3. Fix duplicated genes (`agat_sp_fix_features_locations_duplicated.pl`).
4. Fix the phase of the CDSs (`agat_sp_fix_cds_phases.pl`).
5. Remove overlaps (`agat_sp_fix_overlaping_genes.pl`).
6. Add Introns (`agat_sp_add_introns.pl`).
7. Add start and stop codons (`agat_sp_add_start_and_stop.pl`).
8. Remove unwanted attributes (`agat_sp_manage_attributes.pl`).
9.  Re-sort the file for re-naming (`agat_convert_sp_gxf2gxf.pl`).
10. Clean the IDs (`agat_sp_manage_IDs.pl`).
11. Extract the gene/mRNA attribute IDs (`agat_sp_extract_attributes.pl`).
12. Convert the IDs into an attribute table (Uses BASH commands).
13. Add the attributes into a new, final GFF (`agat_sq_add_attributes_from_tsv.pl`).
14. Extract the peptide sequences (`agat_sp_extract_sequences.pl`).
15. Extract the CDS sequences (`agat_sp_extract_sequences.pl`).
16. Calculate the basic AGAT stats (`agat_sq_stat_basic.pl`).
17. Calculate some more detailed stats (`agat_sp_statistics.pl`).

#### Functional annotation

The directory `scripts/genome_annotation/functional` contains the configuration files for running
`EnTap` version `2.3.0`:

* `entap_config.ini`
* `entap_run.params`

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

## Reference sample popgen

The directory `scripts/popgen/reference_sample` contains a series of scripts for
calculating diversity statistics on the *B. glandula* reference individual,
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

Filter the variants using `BCFtools` version `1.21` `filter` and `view`.

* `run_snpEff.sh`

Take the set of called variants and annotate their effects using `snpEff` version `5.2`.
First, the script builds a `snpEff` database. Then, it annotates the VCF.

## Barnacle comparative genomics

In addition to the newly-generated assemblies for *Balanus glandula* and
*Balanus crenatus*, we used publicly available data from the following species:

| Spp name | Class | Family | Spp Code | NCBI Accession | Assembly ID | In OrthoDB v11<sup>1</sup> | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | 
| *Amphibalanus amphitrite* | Thecostraca | Balanidae | `AmpAmp` | `GCF_019059575.1` | NRLGWU_Aamphi_draft | yes | RefSeq genome |
| *Amphibalanus amphitrite* | Thecostraca | Balanidae | `AmpAmp` | `GCA_037642225.1` | ASM3764222v1 | no | Lifting over annotation from `GCF_019059575.1` |
| *Capitulum mitella* | Thecostraca | Pollicipedidae | `CapMit` | `GCA_030062745.1` | ASM3006274v1 | no | No annotation |
| *Pollicipes pollicipes* | Thecostraca |  Pollicipedidae | `PolPol` | `GCF_011947565.3` | Ppol_2.1 | yes | RefSeq genome |

The `scripts/comparative_genomics/` directory contains various subdirectories describing
various comparative genomic analyses, including identifying orthologs, synteny, whole-
genome aligments, etc.

### Identifying orthogroups

`scripts/comparative_genomics/orthofinder`:

* `run_orthofinder.sh`

Identify orthologous genes across barnacle genomes using `OrthoFinder` version `3.1.0`.

### Conserved synteny analysis

`scripts/comparative_genomics/synteny`:

* `synolog_cache.sh`

Manages a species cache in `Synolog` version `1.0`. Uses the `synolog_cctl.py`
script to create a new cache, and adds a new species with its corresponding
annotation and gene sequences.

* `synolog_blasts.sh`

Run and manage the pairwise `BLAST`s for an existing `Synolog` cache.

* `synolog_run.sh`

Run the main `Synolog` reference algorithm on the existing cache and `BLAST`
results. Then, generate a genome-wide synteny plot using `synolog_plot.py`.

### Whole-genome alignment and conserved regions

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

### dN/dS analysis

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

### McDonald-Kreitman test

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

### Codon usage biases

`scripts/comparative_genomics/codon_usage`

* `run_cubar.sh`

Take a set of coding sequences in FASTA format and calculate codon
usage using the `cubar` version `1.2.0` R package. The script does a
few statistics, but the main one we care about here is the effective
number of codons (ENC).

## Oregon *Balanus glandula* population genetics

### Sample information and sequencing

Raw data available on NCBI BioProject
[PRJNA1434535](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA1434535).

| Sample ID | Location | Date Collected | NCBI BioSample |
| - | - | - | - |
| Bgland_CPE_1  | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729179 |
| Bgland_CPE_11 | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729185 |
| Bgland_CPE_12 | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729186 |
| Bgland_CPE_2  | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729180 |
| Bgland_CPE_3  | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729181 |
| Bgland_CPE_4  | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729182 |
| Bgland_CPE_5  | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729183 |
| Bgland_CPE_9  | Cape Perpetua, Yachats, Oregon, USA | Aug 2023 | SAMN56729184 |

### Population genetics analyses

The directory `scripts/popgen/oregon` contains various script for analysing the population
genetics data for central Oregon barnacles. This includes the alignment and genotyping
of individuals as well as various downstream analyses.

* `bwa_align_reads.sh`
  
Align the processed Illumina short reads for the eight samples using `bwa mem` version
`0.7.18-r1243`. Process the resulting alignments with `samtools` version `1.21`.
Calculate depth of coverage using `mosdepth` version `0.3.10`.

* `run_bcftools_chr.sh`

Use `BCFtools` version `1.21` `mpileup` and `call` to genotype the six Oregon barnacle
sam individuals. Run the genotyping per-chromosome.

* `filt_bcf_4pixy.sh`

Filter the variants using `BCFtools` version `1.21` `filter` and `view`.

* `run_pixy.sh`

Take the processed genotypes and calculate population genetic statistics (e.g.,
pi and Watterson's theta) using `pixy` version `2.0.0.beta12`. By default,
calculate these statistics over the whole genome within 10 kbp windows.

* `run_pixy_features.sh`

Take the processed genotypes and calculate diversity over specific genomic features
(e.g., coding exons, introns, intergenic) using `pixy` version `2.0.0.beta12`. The
coordinates of the features of interest are specified in BED format.

* `run_degenotate.sh`

Run `degenotate` version `1.3` to calculate the degeracy of the coding sites in the
*B. glandula* reference annotation.

### Demographic inference

`scripts/popgen/ne_inference`

* `run_deminfhelper.sh`

Run `msmc2` version `2.1.4` as implemented in `DemInfHelper`.

* `Bgland_00.yml`

Example of the configuration file required by `DemInfHelper`.

### Allozyme analysis

The directory `scripts/allozymes/` contains scripts for the identification and
analysis of the classic allozyme loci, including calculating synonymous diversity
and divergence.

* `pairwise_Ks.py`

Custom Python script to calculate the pairwise synonymous substitution rate between
aligned nucleotide sequences. It uses the Python `dnds` and `BioPython` packages.

Usage:

```sh
$ python3 pairwise_Ks.py -h
pairwise_Ks.py started on 2026-04-10 17:28:46.
usage: pairwise_Ks.py [-h] -l SCO_LIST -a ALIGNMENTS -i INGROUP
                      [-o OUT_DIR] [-w WINDOW_LEN] [-m MIN_ALN_LEN]
                      [-s ALN_SUFFIX]

options:
  -h, --help            show this help message and exit
  -l SCO_LIST, --sco-list SCO_LIST
                        (str) Path to the single-copy orthgroup table
                        (produced by `extract_orthogroups_cds.py`).
  -a ALIGNMENTS, --alignments ALIGNMENTS
                        (str) Path to the directory with the trimmed
                        multiple sequence alignments.
  -i INGROUP, --ingroup INGROUP
                        (str) ID of the ingroup (focal) species in the
                        alignment. Used to report gene/transcript IDs in
                        the output.
  -o OUT_DIR, --out-dir OUT_DIR
                        (str) Path to output directory [default=./].
  -w WINDOW_LEN, --window-len WINDOW_LEN
                        (int) Window length over which to calculate
                        silent substitution rate (Ks) [default=9]
  -m MIN_ALN_LEN, --min-aln-len MIN_ALN_LEN
                        (int) Minimum length required to keep an
                        alignment [default=25]
  -s ALN_SUFFIX, --aln-suffix ALN_SUFFIX
                        (str) Suffix for the alignment FASTA files
                        [default=fa].
```

* `run_pixy.sh`

Calculate nucleotide diversity using `pixy` version `2.0.0.beta12`. This script
calcuate per-site Pi.

* `process_pi4_Ks.R`

Custom R script that combines the Ks and Pi results to calculate per-codon and
per-window estimates of the rate of synonymoyus diversity to divergence (`Pi_4/K_S`).

* `run_stitch_pipeline.sh`

Pipeline to process the allozyme MSAs, extract flanking sequences, and run an HKA
analysis using `sliding_hka`.

## *Balanus crenatus* genome assembly and annotation

* The wrinkled barnacle (*Balanus crenatus*).
* NCBI TaxID: [164412](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=164412)

### Sample information and sequencing

Raw data available on NCBI BioProject [PRJNA1378260](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA1378260).

| Sequencing | Location | Date Collected | NCBI BioSample |
| - | - | - | - |
| PacBio HiFi | Oregon Institute of Marine Biology, Charleston, OR, USA | Nov 2023 | SAMN56729178 |

### Genome assembly

The directory `scripts/crenatus/genome_assembly` contains scripts for the assembly
of the genome of *B. crenatus*.

#### K-mer estimation

* `run_jellyfish.sh`:
 
Use `jellyfish` version `2.1.10` to count k-mers (`jellyfish count`)
and generate a k-mer histogram (`jellyfish histo`).

* `run_genomescope.sh`

Use `GenomeScope2` version `2.0` to do the k-mer model and plot.

#### Contig-level assembly

* `run_hifiasm.sh`

Generate a contig-level assembly using `hifiasm` version `0.19.8-r603`. This run contains
strict parameter for the identification and purging of haplotig sequences.

* `run_quast.sh`

Assess contiguity of the contig-level assembly using `quast` version `5.2.0`.

* `run_compleasm.sh`

Assess gene-completeness of the assembly using `compleasm` version `0.12-r237`, comparing
against the `arthropoda_odb10` reference dataset.

#### Filtering contamination

Filtering contamination by running `MMseqs2` Release `15-6f452`.

* `createindex.sh`

Create the `mmseqs2` index.

* `taxpercontig.sh`

Use `mmseqs2` to assign taxonomy per contig.

* `filter_mmseq_fasta.sh`

Used the `mmseqs` assignments and filter the assembly. We only selected sequences
matching the target NCBI taxonomical ID (Thecostraca:
[116172](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=116172&lvl=3&lin=f&keep=1&srchmode=1&unlock)).

#### Purging haplotig sequences

* `run_pd_mininap.sh`

This scripts aligns the HiFi reads back to the assembly and calculates some coverage
statistics for identifying haplotigs.

1. Align the filtered reads to the optimized contig-level
assembly using `minimap2` version `2.26-r1175`.
2. Use `pbcstat` tool from `purge_dups` version `1.2.5` to
calculate the read-depth histogram.
3. Use `calcuts` tool from `purge_dups` version `1.2.5` to
calculate the base-level depth coverage cutoffs.
4. Split the genome for self alignment using `split_fa`.
5. Do the self alignment of the genome with `minimap2` version
`2.26-r1175`.

* `run_purge_dups.sh`

This script removes haplotig sequences from the assembly in the following
steps:

1. Use `purge_dups` version `1.2.5` to mark the duplicate sequences in
a BED file.
2. Process the assembly to extract the haplotig sequences using `get_seqs`.

#### Correcting sequences

* `run_inspector.sh`

Perform a round of self-correction in the assembly using `inspector` version
`1.0.1`. This scripts first runs `inspector.py` to align the reads and 
evaluate the assembly, and then it corrects any errors using
`inspector-correct.py`.

#### Reference-guided scaffolding

Scaffold the purged, contig-level assembly using `ragout` version `2.3`. This
takes as input the `cactus` whole-genome assemblies, taking *B. glandula* as the
reference.

#### Repeat annotation

* `run_earlGrey.sh`

Annotate repeats in the scaffolded *B. crenatus* assembly using `EarlGrey` version
`4.0.1`.

#### Annotation liftover

* `run_lifton.sh`

Annotate the *B. crenatus* assembly by lifting over the gene models from our curated
*B. glandula* annotation. The liftover was done using `LiftOn` version `1.0.5`.

* `run_compleasm.sh`

Assess the gene-completeness of the lifted-over annotation using `compleasm`
version `0.12-r237` in `protein` mode. This compares against the `arthropoda_odb10`
reference `BUSCO` ortholog set.

## *Drosophila* comparisons

The directory `scripts/dmel` contains several script for generating comparative
statistics in *Drosophila melanogaster*, including nucleotide diversity and
codon usage biases.

### Nucleotide diversity

Calculate nucleotide diversity from the `RG` Sub-Saharan population of the DPGP2
dataset.

* `extract_gvcf.sh`

Use `snp-sites` version `2.5.1` to process the DPGP2 aligned FASTAs into a VCF
containing both variant and invariant sites.

* `process_vcfs.sh`

Process the raw gVCFs and recode deletions (using the custom `recode_deletions.awk` script)
and clean and filter the VCF using `BCFtools` versions `1.21`.

* `recode_deletions.awk`

Custom AWK command to parse the VCF and recode deletions. The deletions come from the gaps
in the alignment and are coded as missing genotypes.

* `run_pixy_py.sh`

Calculate nucleotide diversity from the filtered VCF using `pixy` version `2.0.0.beta12`.

### Codon biases

* `run_cubar.R`
* 
Take a set of coding sequences in FASTA format and calculate codon
usage using the `cubar` version `1.2.0` R package. The script does a
few statistics, but the main one we care about here is the effective
number of codons (ENC).

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
