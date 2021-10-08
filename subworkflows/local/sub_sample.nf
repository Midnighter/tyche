//
// Prepare seed and sample size per input reads.
//

params.options = [:]

if (params.options.genome_size && params.options.coverage) {
    params.options.size = [params.options.genome_size, params.options.coverage]
        .transpose()
        .collect { "--genome-size ${it[0]} --coverage ${it[1]}" }
    params.options.name = [params.options.genome_size, params.options.coverage]
        .transpose()
        .collect { "${it[0]}_${it[1]}" }
    params.options.rasusa = [params.options.size, params.options.name].transpose()
    for (size in params.options.size) {
        log.info "Running rasusa with ${size}."
    }
} else if (params.options.bases) {
    params.options.size = params.options.bases.collect { "--bases ${it}" }
    params.options.name = params.options.bases.clone()
    params.options.rasusa = [params.options.size, params.options.name].transpose()
    for (size in params.options.size) {
        log.info "Running rasusa with ${size}."
    }
} else if (params.options.reads_num) {
    params.options.name = params.options.reads_num.clone()
    params.options.seqtk = [params.options.reads_num, params.options.name].transpose()
    for (size in params.options.reads_num) {
        log.info "Running seqtk with ${size} samples."
    }
} else {
    log.error 'You *must* specify either both the desired --coverage and --genome_size, the number of --bases, or the --reads_num to be sampled.'
    exit 2
}

include { RASUSA } from '../../modules/local/rasusa' addParams( options: params.options.modules.rasusa )
include { SEQTK_SAMPLE  } from '../../modules/nf-core/modules/seqtk/sample/main'  addParams( options: params.options.modules['seqtk/sample'] )

workflow SUB_SAMPLE {
    take:
    reads // channel: [ val(meta), [ reads ] ]

    main:
    def seeds = Channel.fromList(generate_seeds())

    if (params.options.size) {
        def size = Channel.fromList(params.options.rasusa)
        RASUSA(
            reads.combine(seeds)
                .combine(size)
                .map { fortify_id(it) }
        )
        ch_reads = RASUSA.out.reads
        ch_versions = RASUSA.out.versions
    } else {
        def num = Channel.fromList(params.options.seqtk)
        SEQTK_SAMPLE(
            reads.combine(seeds)
                .combine(num)
                .map { fortify_id(it) }
        )
        ch_reads = SEQTK_SAMPLE.out.reads
        ch_versions = SEQTK_SAMPLE.out.versions
    }

    emit:
    reads = ch_reads // channel: [ val(meta), [ reads ] ]
    versions = ch_versions
}

// Generate a different positive seed for each requested replicate.
def generate_seeds() {
    if (params.options.seeds.size() >= params.options.replicates) {
        return params.options.seeds
    }
    // Use first seed to reproducibly generate the new seeds.
    // One seed must exist and is typically the default 100.
    def rng = new Random(params.options.seeds[0])
    def Set<Integer> seeds = []
    while (seeds.size() < params.options.replicates) {
        seeds.add(Math.abs(rng.nextInt()))
    }
    return seeds
}

// Fortify the id with meta information.
def fortify_id(row) {
    def meta = row[0].clone()
    def reads = row[1]
    def seed = row[2]
    def sample = row[3]
    def name = row[4]

    meta.original_id = meta.id
    meta.id = "${meta.id}_${seed}_${name}"
    return [meta, reads, seed, sample]
}
