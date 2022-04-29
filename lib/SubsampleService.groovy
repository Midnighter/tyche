import ch.qos.logback.classic.Logger

/**
 * Provide a service with helper methods for generating subsamples.
 */
class SubsampleService {

    /**
    * Extend a single sample with additional meta information.
    *
    * @param row A single row represented by the meta information map and reads.
    * @param tool A string denoting the sampling tool that will be used.
    * @param arguments A list of combinations of random seed numbers and tool options.
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
            meta.sample_args = values[1]
            result << [meta, reads, values[0], values[1]]
        }
        return result
    }

    /**
    * Select the sampling tool and generate sampling arguments.
    *
    * @param options The map of options passed to the subsample workflow.
    * @param log The nextflow logger object.
    * @return Pair of the selected tool and a list of one or more sampling arguments.
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
            tool = 'fq'
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

    /**
    * Convert a sample into a CSV format suitable for `collectFile`.
    *
    * @param row A single row represented by the meta information map and reads.
    * @return A pair of a dynamic filename and text to write to that file.
    */
    static Tuple sampleToCSV(List row) {
        Map meta = row[0].clone()
        List reads
        if (meta.single_end) {
            reads = [row[1]]
        } else {
            reads = row[1]
        }
        return ["${meta.original_id}.csv", this.prepareCSV(meta, reads)]
    }

    /**
    * Convert a sample into CSV format with header.
    *
    * @param meta A map describing the sample.
    * @param reads A list of one or two paths to FastQ files.
    * @return A CSV string with header describing the sample.
    */
    private static String prepareCSV(Map meta, List reads) {
        Map sample = [
            sample: meta.id,
            original_sample: meta.original_id,
            fastq_1: reads[0].name,
            fastq_2: meta.single_end ? '' : reads[1].name
        ]
        meta.remove('id')
        meta.remove('original_id')
        meta.remove('fastq_1')
        meta.remove('fastq_2')
        sample.putAll(meta)
        List fields = ['sample', 'original_sample', 'fastq_1', 'fastq_2'] + meta.keySet()
        String result = fields.join(',')
        result += '\n'
        result += fields.collect { key -> sample[key] }.join(',')
        result += '\n'
        return result
    }

}
