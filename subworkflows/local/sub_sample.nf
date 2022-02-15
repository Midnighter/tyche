//
// Prepare seed and sample size per input reads.
//

params.options = [:]

include { RASUSA } from '../../modules/local/rasusa' addParams( options: params.options.modules.rasusa )
include { FQ_SUBSAMPLE } from '../../modules/local/fq_subsample' addParams( options: params.options.modules['seqtk/sample'] )
include { DECOMPRESS } from '../../modules/local/decompress'
// include { SEQTK_SAMPLE  } from '../../modules/nf-core/modules/seqtk/sample/main'  addParams( options: params.options.modules['seqtk/sample'] )

workflow SUB_SAMPLE {
    take:
    reads // channel: [ val(meta), [ reads ] ]

    main:
    // Prepare sampling tool arguments and seeds per replicate.
    def (String tool, List sample_args) = SubsampleService.selectToolWithArgs(params.options, log)
    List<Integer> seeds = SubsampleService.generateSeeds(params.options)
    List arguments = [seeds, sample_args].combinations()
    // Decompress reads if necessary.
    if (tool == 'seqtk') {
        ch_decompress = DECOMPRESS(reads).out.reads
    } else {
        ch_decompress = reads
    }
    // Duplicate each input by the arguments.
    def samples = ch_decompress
        .flatMap { sample -> SubsampleService.extendSample(sample, tool, arguments) }

    if (tool == 'rasusa') {
        RASUSA(samples)

        ch_reads = RASUSA.out.reads
        ch_versions = RASUSA.out.versions
    } else if (tool == 'seqtk') {
        // SEQTK_SAMPLE(samples)
        FQ_SUBSAMPLE(samples)

        // ch_reads = SEQTK_SAMPLE.out.reads
        ch_reads = FQ_SUBSAMPLE.out.reads
        // ch_versions = SEQTK_SAMPLE.out.versions
        ch_versions = []
    } else {
        log.error "Unknown sampling tool ${tool}."
        exit 2
    }

    // Create sample sheets for the subsampled reads.
    ch_reads.collectFile(
        storeDir: "${params.outdir}/csv",
        keepHeader: true,
        sort: true
    ) { row -> SubsampleService.sampleToCSV(row) }
    .collectFile(
        name: 'subsamplesheet.csv',
        storeDir: params.outdir,
        keepHeader: true,
        sort: true
    )

    emit:
    reads = ch_reads // channel: [ val(meta), [ reads ] ]
    versions = ch_versions
}
