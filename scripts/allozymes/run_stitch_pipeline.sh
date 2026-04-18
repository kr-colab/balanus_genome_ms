#!/usr/bin/env bash
# Reproduce the per-locus stitched BalGla/BalCre alignment pipeline end-to-end.
#
# Steps:
#   1. Find each allozyme locus in the current BalGla assembly (kmer match).
#   2. Extract BalGla gene + FLANK window per locus.
#   3. Map the BalGla CDS of each locus to BalCre via minimap2 splice.
#   4. Extract BalCre gene + FLANK window per locus.
#   5. Pairwise-align each BalGla/BalCre window with lastz.
#   6. Stitch: codon-aware CDS portions from msas/ + lastz non-coding + flanks.
#   7. Locate each locus in the older scaffold-named BalGla assembly that the
#      VCFs were called against.
#   8. Extract per-sample diploid haplotypes from the all-sites VCFs.
#   9. Build per-locus full MSAs (stitched pair + 12 ingroup haplotypes).
#  10. Build per-position annotation TSVs for the full MSAs.
#  11. Run the annotated sliding-HKA diagnostic across all loci (joint T+1).
#
# Prerequisites (in PATH or in the bioinfo-buddy conda env):
#   uv, samtools, minimap2, lastz, mafft, bcftools
#
# Required inputs:
#   - msas/*.fa                  (codon-aware CDS MSAs: Bgland_* + Bcrena_*)
#   - ${WGA_DIR}/BalGla.fa{,.fai}
#   - ${WGA_DIR}/BalGla.gff
#   - ${WGA_DIR}/BalCre.fa{,.fai}
#   - ${WGA_DIR}/BalGla_BalCre_alignment/BalGla_cds.fa (AnchorWave-extracted CDS)
#   - ${OLD_ASSEMBLY}                      (scaffold-named BalGla used by the VCFs)
#   - ${VCF_DIR}/Bglandula.<scaffold>.flt.allsites.snp.vcf.gz (+ .tbi)
#
# Environment variables (override by prefixing the invocation):
#   WGA_DIR        - AnchorWave directory root
#   OLD_ASSEMBLY   - scaffold-named BalGla FASTA that the VCFs were called against
#   VCF_DIR        - directory of per-scaffold all-sites VCFs
#   SAMPLES        - space-separated list of Bgland sample IDs (default: 6 samples)
#   FLANK          - bp to extend each locus window (default 5000)
#   THREADS        - minimap2 / lastz / mafft threads (default 4)
#   WINDOW         - silent-site sliding-window width for HKA plots (default 500)
#   LASTZ_OPTS     - override lastz parameters (defaults to permissive sister-species set)
#
# Usage:
#   scripts/run_stitch_pipeline.sh
#   FLANK=10000 scripts/run_stitch_pipeline.sh

set -euo pipefail

# ---- locations ----
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

WGA_DIR="${WGA_DIR:-/sietch_colab/data_share/balanus/comp_genomics/whole_genome_alignments/20260414.AnchorWave}"
BALGLA="${WGA_DIR}/BalGla.fa"
BALCRE="${WGA_DIR}/BalCre.fa"
BALGLA_CDS="${WGA_DIR}/BalGla_BalCre_alignment/BalGla_cds.fa"
BALGLA_GFF="${WGA_DIR}/BalGla.gff"

OLD_ASSEMBLY="${OLD_ASSEMBLY:-/sietch_colab/data_share/balanus/popgen/202406-analysis/bwa_index/B_glandula.v1.chr15.fa}"
VCF_DIR="${VCF_DIR:-/sietch_colab/data_share/balanus/popgen/202406-analysis/vcfs}"
SAMPLES="${SAMPLES:-Bgland_1 Bgland_2 Bgland_3 Bgland_4 Bgland_5 Bgland_11}"

FLANK="${FLANK:-5000}"
THREADS="${THREADS:-4}"
WINDOW="${WINDOW:-500}"

# Permissive lastz settings for sister-species pairwise alignment. The short
# match-8 seed + relaxed HSP/gapped thresholds recover more intron coverage
# than the lastz defaults without noticeably hurting CDS identity.
# Override by exporting LASTZ_OPTS="--format=maf ...".
LASTZ_OPTS="${LASTZ_OPTS:---format=maf --strand=both --gapped --chain --seed=match8 --hspthresh=1500 --gappedthresh=1000 --ydrop=9400 --inner=2000}"

# ---- sanity checks ----
for f in "$BALGLA" "$BALCRE" "$BALGLA_CDS" "$BALGLA_GFF"; do
    [ -r "$f" ] || { echo "missing input: $f" >&2; exit 1; }
done
for f in "$BALGLA.fai" "$BALCRE.fai"; do
    [ -r "$f" ] || { echo "missing index: $f (run samtools faidx)" >&2; exit 1; }
done
for cmd in samtools minimap2 lastz mafft bcftools uv; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "missing tool: $cmd" >&2; exit 1; }
done
[ -r "$OLD_ASSEMBLY" ]      || { echo "missing OLD_ASSEMBLY: $OLD_ASSEMBLY" >&2; exit 1; }
[ -r "$OLD_ASSEMBLY.fai" ]  || { echo "missing OLD_ASSEMBLY index: $OLD_ASSEMBLY.fai" >&2; exit 1; }
[ -d "$VCF_DIR" ]           || { echo "missing VCF_DIR: $VCF_DIR" >&2; exit 1; }

mkdir -p data \
    out/per_locus_aln/{balgla,balcre,cds,aligned,stitched,haplotypes,full_msa}

LOCUS_MAP="data/locus_map.tsv"
LOCUS_MAP_BC="data/locus_map_with_balcre.tsv"

# ---- 1. locate each allozyme in new BalGla assembly ----
echo "[1/11] finding loci in BalGla assembly..."
uv run python scripts/find_loci_in_assembly.py \
    --msa-dir msas \
    --balgla-cds "$BALGLA_CDS" \
    --balgla-gff "$BALGLA_GFF" \
    --output "$LOCUS_MAP"

# ---- 2. extract BalGla gene+flank windows ----
echo "[2/11] extracting BalGla windows (flank=${FLANK})..."
tail -n +2 "$LOCUS_MAP" | while IFS=$'\t' read -r locus mrna gene chrom start end strand; do
    ws=$((start - FLANK)); [ "$ws" -lt 1 ] && ws=1
    we=$((end + FLANK))
    out="out/per_locus_aln/balgla/${locus}.fa"
    samtools faidx "$BALGLA" "${chrom}:${ws}-${we}" > "$out"
    sed -i "1s|.*|>BalGla_${locus} chrom=${chrom} start=${ws} end=${we} gene=${gene} strand=${strand}|" "$out"
    printf "  %-6s %s:%d-%d\n" "$locus" "$chrom" "$ws" "$we"
done

# ---- 3. map CDS to BalCre, derive BalCre windows ----
echo "[3/11] mapping CDS to BalCre..."
uv run python scripts/derive_balcre_windows.py \
    --locus-map "$LOCUS_MAP" \
    --balgla-cds "$BALGLA_CDS" \
    --balcre "$BALCRE" \
    --outdir out/per_locus_aln/cds \
    --output "$LOCUS_MAP_BC" \
    --threads "$THREADS"

# ---- 4. extract BalCre gene+flank windows ----
echo "[4/11] extracting BalCre windows (flank=${FLANK})..."
tail -n +2 "$LOCUS_MAP_BC" | while IFS=$'\t' read -r locus bg_chrom bg_s bg_e bg_strand bc_chrom bc_s bc_e bc_strand bc_span; do
    ws=$((bc_s - FLANK)); [ "$ws" -lt 1 ] && ws=1
    we=$((bc_e + FLANK))
    out="out/per_locus_aln/balcre/${locus}.fa"
    samtools faidx "$BALCRE" "${bc_chrom}:${ws}-${we}" > "$out"
    sed -i "1s|.*|>BalCre_${locus} chrom=${bc_chrom} start=${ws} end=${we} strand=${bc_strand}|" "$out"
    printf "  %-6s %s:%d-%d (%s)\n" "$locus" "$bc_chrom" "$ws" "$we" "$bc_strand"
done

# ---- 5. pairwise lastz alignment per locus ----
echo "[5/11] running lastz per locus (LASTZ_OPTS=${LASTZ_OPTS})..."
for locus in $(tail -n +2 "$LOCUS_MAP" | cut -f1); do
    bg="out/per_locus_aln/balgla/${locus}.fa"
    bc="out/per_locus_aln/balcre/${locus}.fa"
    maf="out/per_locus_aln/aligned/${locus}.lastz.maf"
    log="out/per_locus_aln/aligned/${locus}.lastz.log"
    # shellcheck disable=SC2086  # intentional word-splitting of LASTZ_OPTS
    lastz "$bg" "$bc" $LASTZ_OPTS > "$maf" 2> "$log"
    n_blocks=$(grep -c "^a" "$maf" || true)
    printf "  %-6s %d blocks\n" "$locus" "$n_blocks"
done

# ---- 6. stitch codon-aware CDS with lastz non-coding ----
echo "[6/11] stitching per-locus alignments..."
uv run python scripts/stitch_per_locus.py

# ---- 7. locate each locus in the old scaffold assembly ----
echo "[7/11] locating loci in old scaffold assembly..."
uv run python scripts/find_loci_in_old_assembly.py \
    --msa-dir msas \
    --old-assembly "$OLD_ASSEMBLY" \
    --output data/locus_map_old_assembly.tsv \
    --threads "$THREADS"

# ---- 8. extract per-sample haplotypes via bcftools consensus ----
echo "[8/11] extracting per-sample haplotypes..."
uv run python scripts/extract_sample_haplotypes.py \
    --locus-map data/locus_map_old_assembly.tsv \
    --vcf-dir "$VCF_DIR" \
    --vcf-pattern 'Bglandula.{scaffold}.flt.allsites.snp.vcf.gz' \
    --old-reference "$OLD_ASSEMBLY" \
    --samples $SAMPLES \
    --outdir out/per_locus_aln/haplotypes \
    --flank "$FLANK"

# optional but cheap: confirm CDS of haplotypes matches the codon-aware MSAs
uv run python scripts/sanity_check_haplotypes.py \
    --msa-dir msas \
    --hap-dir out/per_locus_aln/haplotypes \
    > out/per_locus_aln/haplotypes/sanity_check.txt
echo "  (sanity check written to out/per_locus_aln/haplotypes/sanity_check.txt)"

# ---- 9. build per-locus full MSA (stitched pair + 12 haplotypes) ----
echo "[9/11] building full per-locus MSAs..."
uv run python scripts/build_full_msa.py --threads "$THREADS"

# ---- 10. build per-position annotation TSVs for full MSAs ----
echo "[10/11] building per-position annotation TSVs..."
uv run python scripts/build_annotation.py --gff "$BALGLA_GFF"

# ---- 11. run annotated sliding HKA (joint T+1, full MSAs) ----
echo "[11/11] running annotated sliding HKA (joint T+1, w=${WINDOW} silent sites)..."
mkdir -p out/hka/full_joint
uv run sliding-hka run out/per_locus_aln/full_msa/*.full.fa \
    --outdir out/hka/full_joint \
    --window "$WINDOW" \
    --outgroup-match BalCre_ \
    --ingroup-match Bgland_ \
    --annotation-dir out/per_locus_aln/annotation \
    --joint-t

echo ""
echo "done. outputs:"
echo "  - stitched BalGla/BalCre pair:  out/per_locus_aln/stitched/"
echo "  - full per-locus MSA:           out/per_locus_aln/full_msa/"
echo "  - per-position annotations:     out/per_locus_aln/annotation/"
echo "  - sliding HKA plots:            out/hka/full_joint/"
