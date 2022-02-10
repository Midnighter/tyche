// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SEQTK_SAMPLE {
    tag "${meta.id}"

    publishDir params.outdir,
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? 'bioconda::seqtk=1.3' : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container 'https://depot.galaxyproject.org/singularity/seqtk:1.3--h5bf99c6_3'
    } else {
        container 'quay.io/biocontainers/seqtk:1.3--h5bf99c6_3'
    }

    input:
    tuple val(meta), path(reads), val(seed), val(size)

    output:
    tuple val(meta), path("*${reads_format}"), emit: reads
    path 'versions.yml',                       emit: versions

    script:
    reads_format = meta.single_end ? reads.name - reads.simpleName : reads[0].name - reads[0].simpleName
    def prefix   = options.suffix ? "${meta.id}${options.suffix}" : meta.id
    if (meta.single_end) {
        // Cannot use `def` since it causes compilation errors complaining about redefining variables.
        output = reads_format.endsWith('.gz') ? "| gzip --no-name > '${prefix}${reads_format}'" : "> '${prefix}${reads_format}'"
        """
        seqtk sample \\
            -s ${seed} \\
            -2 \\
            ${options.args} \\
            ${reads} \\
            ${size} ${output}

        cat <<-END_VERSIONS > versions.yml
        ${getProcessName(task.process)}:
            ${getSoftwareName(task.process)}: \$(echo \$(seqtk 2>&1) | sed 's/^.*Version: //; s/ .*\$//')
        END_VERSIONS
        """
    } else {
        // Cannot use `def` since it causes compilation errors complaining about redefining variables.
        output1 = reads_format.endsWith('.gz') ? "| gzip --no-name > '${prefix}_1${reads_format}'" : "> '${prefix}_1${reads_format}'"
        output2 = reads_format.endsWith('.gz') ? "| gzip --no-name > '${prefix}_2${reads_format}'" : "> '${prefix}_2${reads_format}'"
        """
        seqtk \
            sample \
            ${options.args} \
            -s ${seed} \
            ${reads[0]} \
            ${size} ${output1}

        seqtk \
            sample \
            ${options.args} \
            -s ${seed} \
            ${reads[1]} \
            ${size} ${output2}

        cat <<-END_VERSIONS > versions.yml
        ${getProcessName(task.process)}:
            ${getSoftwareName(task.process)}: \$(echo \$(seqtk 2>&1) | sed 's/^.*Version: //; s/ .*\$//')
        END_VERSIONS
        """
    }
}
