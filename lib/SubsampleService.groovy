import ch.qos.logback.classic.Logger

/**
 * Provide a service for generating subsamples.
 */
class SubsampleService {

    /**
    * Extend a single sample with additional meta information.
    *
    * @param row A single row represented by the meta information map and reads.
    * @return List of extended meta maps and reads.
    */
    static List extendSample(List row, String tool, List arguments) {
        List result = []
        Map meta
        List reads
        arguments.eachWithIndex { List values, Integer idx ->
            meta = row[0].clone()
            reads = row[1]

            meta.original_id = meta.id
            meta.id = "${meta.original_id}_S${idx + 1}"
            meta.tool = tool
            meta.seed = values[0]
            meta.args = values[1]
            result << [meta, reads, values[0], values[1]]
        }
        return result
    }

    /**
    * Select the sampling tool and generate sampling arguments.
    *
    * @param options The map of options passed to the subsample workflow.
    * @param log The nextflow logger object.
    * @return Pair of the selected tool and one or more sampling arguments.
    */
    static Tuple selectToolWithArgs(Map options, Logger log) {
        List<String> sampleArgs
        String tool
        if (options.genome_size && options.coverage) {
            tool = 'rasusa'
            sampleArgs = [options.genome_size, options.coverage]
                .transpose()
                .collect { pair -> "--genome-size ${pair[0]} --coverage ${pair[1]}" }
        } else if (options.bases) {
            tool = 'rasusa'
            sampleArgs = options.bases.collect { "--bases ${it}" }
        } else if (options.reads_num) {
            tool = 'seqtk'
            sampleArgs = options.reads_num.clone()
        } else {
            log.error 'You *must* specify either both the desired --coverage and --genome_size, the number of --bases, or the --reads_num to be sampled.'
            System.exit 2
        }
        for (arg in sampleArgs) {
            log.info "Run ${tool} with '${arg}'."
        }
        return [tool, sampleArgs]
    }

    /**
    * Generate a different natural number seed for each requested replicate.
    *
    * @param options The map of options passed to the subsample workflow.
    * @return List of seeds.
    */
    static List<Integer> generateSeeds(Map options) {
        if (options.seeds.size() >= options.replicates) {
            return options.seeds
        }
        // Use the first seed to reproducibly generate new seeds.
        // One seed must exist and is typically the default 100.
        Random rng = new Random(options.seeds[0])
        Set<Integer> seeds = [] as Set
        while (seeds.size() < options.replicates) {
            seeds.add(Math.abs(rng.nextInt()))
        }
        return seeds as List
    }

}
