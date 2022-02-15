// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)


process FQ_SUBSAMPLE {
    tag "${meta.id}"
    label 'small_process'

    publishDir params.outdir,
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    input:
    tuple val(meta), path(reads), val(seed), val(size)

    output:
    tuple val(meta), path("${prefix}*.gz"), emit: reads

    script:
    reads_format = meta.single_end ? reads.name - reads.simpleName : reads[0].name - reads[0].simpleName
    is_compressed = reads_format.endsWith('.gz') ? true : false
    // Cannot use `def` since it causes compilation errors complaining about redefining variables.
    input = meta.single_end ? "'${is_compressed ? reads.name - '.gz' : reads.name}'" : "'${is_compressed ? reads[0].name - '.gz' : reads[0].name}' '${is_compressed ? reads[1].name - '.gz' : reads[1].name}'"
    prefix = options.suffix ? "${meta.id}${options.suffix}" : meta.id
    output_format = is_compressed ? reads_format - '.gz' : reads_format
    if (meta.single_end) {
        """
        fq subsample \\
            ${options.args} \\
            --seed ${seed} \\
            --record-count ${size} \\
            --r1-dst '${prefix}${output_format}' \\
            ${input}

        pigz --processes ${task.cpus} '${prefix}*'
        """
    } else {
        """
        fq subsample \\
            ${options.args} \\
            --seed ${seed} \\
            --record-count ${size} \\
            --r1-dst '${prefix}_1${output_format}' \\
            --r2-dst '${prefix}_2${output_format}' \\
            ${input}

        pigz --processes ${task.cpus} ${prefix}*
        """
    }
}
