process DECOMPRESS {
    tag "${meta.id}"
    label 'small_process'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq"), emit: reads

    when:
    is_compressed

    script:
    // Cannot use `def` since it causes compilation errors complaining about redefining variables.
    reads_format = meta.single_end ? reads.name - reads.simpleName : reads[0].name - reads[0].simpleName
    is_compressed = reads_format.endsWith('.gz') ? true : false
    input = meta.single_end ? "'${reads.name}'" : "'${reads[0].name}' '${reads[1].name}'"
    """
    pigz --decompress --force --keep ${input}
    """
}
