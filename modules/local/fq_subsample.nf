// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)


process FQ_SUBSAMPLE {
    tag "${meta.id}"

    publishDir params.outdir,
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    input:
    tuple val(meta), path(reads), val(seed), val(size)

    output:
    tuple val(meta), path("*${reads_format}"), emit: reads
    path 'versions.yml',                       emit: versions

    script:
    reads_format = meta.single_end ? reads.name - reads.simpleName : reads[0].name - reads[0].simpleName
    // Cannot use `def` since it causes compilation errors complaining about redefining variables.
    input = meta.single_end ? "'${reads.name}'" : "'${reads[0].name}' '${reads[1].name}'"
    prefix = options.suffix ? "${meta.id}${options.suffix}" : meta.id
    output   = meta.single_end ?  "'${prefix}${reads_format}'" : "'${prefix}_1${reads_format}' '${prefix}_2${reads_format}'"
    if (meta.single_end) {

    } else {

        """
        fq subsample \\
            ${options.args} \\
            --seed ${seed} \\
            --record-count ${size} \\
            --r1-dst '${prefix}_1${reads_format}' \\
            --r2-dst '${prefix}_2${reads_format}' \\
            "${reads[0]}" "${reads[1]}"

        """
    }
}
