//
// Check input samplesheet and get read channels
//

params.options = [:]
if (params.options.genome_size && params.options.coverage) {
    params.options.size = "--genome-size ${params.options.genome_size} --coverage ${params.options.coverage}"
} else if (params.options.bases) {
    params.options.size = "--bases ${params.options.bases}"
} else {
    log.error 'You must specify either both the desired --coverage and --genome_size or the number of --bases to be sampled.'
    exit 2
}

include { RASUSA } from '../../modules/local/rasusa' addParams( options: params.options )

workflow SUB_SAMPLE {
    take:
    reads // channel: [ val(meta), [ reads ] ]

    main:
    def seeds = Channel.fromList(generate_seeds())
    RASUSA(
        reads.combine( seeds )
        .map { include_seed(it) }
    )

    emit:
    reads = RASUSA.out.reads
    versions = RASUSA.out.versions
}

// Generate a different positive seed for each requested replicate.
def generate_seeds() {
    def seeds = params.seeds.split(',')
        .collect { it.toInteger() }
        .unique()
    if (seeds.size() >= params.options.replicates) {
        return seeds
    }
    // Use first seed to reproducibly generate the new seeds.
    def rng = new Random(seeds[0])
    def Set<Integer> rng_seeds = []
    while (rng_seeds.size() < params.options.replicates) {
        rng_seeds.add(Math.abs(rng.nextInt()))
    }
    return rng_seeds
}

// Include the separately generated seed and sampling info in the meta values.
// [ val(meta), [ reads ], val(seed) ] -> [ val(meta), [ reads ] ]
def include_seed(row) {
    def meta = row[0].clone()
    def reads = row[1]
    def seed = row[2]

    meta.seed = seed
    return [meta, reads]
}
