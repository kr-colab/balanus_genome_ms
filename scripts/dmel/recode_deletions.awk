#!/usr/bin/awk -f

BEGIN {
    FS = OFS = "\t"
}

# Skip header lines
/^#/ {
    print
    next
}

# Process data lines
{
    alt = $5
    
    # Check if ALT contains deletions (*)
    if (alt !~ /\*/) {
        print
        next
    }
    
    # Find which allele numbers correspond to deletions
    n_alts = split(alt, alt_array, ",")
    
    # Create mapping of allele index to deletion status
    for (i = 1; i <= n_alts; i++) {
        is_deletion[i] = (alt_array[i] == "*")
    }
    
    # Process genotype fields (starting from field 10)
    for (i = 10; i <= NF; i++) {
        # Get the genotype field (everything before first colon or the whole field)
        split($i, parts, ":")
        genotype = parts[1]
        
        # Split genotype into alleles (handle / or | separators)
        if (match(genotype, /[\/|]/)) {
            sep = substr(genotype, RSTART, 1)
            split(genotype, alleles, sep)
            
            # Convert deletion alleles to missing
            for (j in alleles) {
                if (alleles[j] != "." && alleles[j] != "0" && is_deletion[alleles[j]]) {
                    alleles[j] = "."
                }
            }
            
            # Reconstruct genotype
            new_genotype = alleles[1] sep alleles[2]
        } else {
            # Haploid or single allele
            if (genotype != "." && genotype != "0" && is_deletion[genotype]) {
                new_genotype = "."
            } else {
                new_genotype = genotype
            }
        }
        
        # Reconstruct the full field
        parts[1] = new_genotype
        new_field = parts[1]
        for (k = 2; k in parts; k++) {
            new_field = new_field ":" parts[k]
        }
        $i = new_field
    }
    
    print
}