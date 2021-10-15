// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process FASTQC {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::fastqc=0.11.9" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/fastqc:0.11.9--0"
    } else {
        container "quay.io/biocontainers/fastqc:0.11.9--0"
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip") , emit: zip
    path  "versions.yml"           , emit: versions

    script:
    reads_format = meta.single_end ? reads.name - reads.simpleName : reads[0].name - reads[0].simpleName
    // Add soft-links to original FastQs for consistent naming in pipeline
    def prefix = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    if (meta.single_end) {
        """
        [ ! -f  ${prefix}${reads_format} ] && ln -s $reads ${prefix}${reads_format}
        fastqc $options.args --threads $task.cpus ${prefix}${reads_format}

        cat <<-END_VERSIONS > versions.yml
        ${getProcessName(task.process)}:
            ${getSoftwareName(task.process)}: \$( fastqc --version | sed -e "s/FastQC v//g" )
        END_VERSIONS
        """
    } else {
        """
        [ ! -f  ${prefix}_1${reads_format} ] && ln -s ${reads[0]} ${prefix}_1${reads_format}
        [ ! -f  ${prefix}_2${reads_format} ] && ln -s ${reads[1]} ${prefix}_2${reads_format}
        fastqc $options.args --threads $task.cpus ${prefix}_1${reads_format} ${prefix}_2${reads_format}

        cat <<-END_VERSIONS > versions.yml
        ${getProcessName(task.process)}:
            ${getSoftwareName(task.process)}: \$( fastqc --version | sed -e "s/FastQC v//g" )
        END_VERSIONS
        """
    }
}
