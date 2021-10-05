// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process RASUSA {
    tag "${meta.id}"
    label 'process_low'
    publishDir params.outdir,
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? 'bioconda::rasusa=0.6.0' : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container 'https://depot.galaxyproject.org/singularity/rasusa:0.6.0--h779adbc_0'
    } else {
        container 'quay.io/biocontainers/rasusa:0.6.0--h779adbc_0'
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*${reads_format}"), emit: reads
    path 'versions.yml',                       emit: versions

    script:
    reads_format = meta.single_end ? reads.name - reads.simpleName : reads[0].name - reads[0].simpleName
    // Cannot use `def` since it causes compilation errors complaining about redefining variables.
    input = meta.single_end ? "'${reads.name}'" : "'${reads[0].name}' '${reads[1].name}'"
    prefix = options.suffix ? "${meta.id}${options.suffix}_${meta.seed}" : "${meta.id}_${meta.seed}"
    output   = meta.single_end ?  "'${prefix}${reads_format}'" : "'${prefix}_1${reads_format}' '${prefix}_2${reads_format}'"
    """
    rasusa \
        ${options.args} \
        --input ${input} \
        --output ${output} \
        --seed ${meta.seed} \
        ${params.options.size}

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${getSoftwareName(task.process)}: \$(rasusa --version 2>&1 | sed -e "s/rasusa //g")
    END_VERSIONS
    """
}
