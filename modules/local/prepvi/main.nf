process PREPVI {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/prepvi:3.7.0':
        'blancojmskcc/prepvi:3.7.0' }"

    input:
    tuple val(meta),  path(mut_file)
    tuple val(meta1), path(pty_file)
    tuple val(meta2), path(cnv_dir)
    tuple val(meta3), path(csv_dir)

    output:
    tuple val(meta), path("*._PRE_PyCloneVI_INN.tsv"), emit: tsv
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def samples = task.ext.prefix ?: "${meta.samples}"
    """
    prepvi \\
        --dnlt . \\
        --patient ${prefix}   \\
        --samples ${samples}  \\
        --dir_cnv ${cnv_dir}  \\
        --dir_csv ${csv_dir}  \\
        --dir_mut ${mut_file} \\
        --dir_purity ${pty_file} \\
        --max_workers ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi: "3.7.0"
    END_VERSIONS
    """
    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """   
    touch ${prefix}_PRE_PyCloneVI_INN.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi: "3.7.0"
    END_VERSIONS
    """
}
