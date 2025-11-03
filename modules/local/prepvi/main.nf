process PREPVI {
    tag "$meta.patient"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/prepvi:3.7.0':
        'blancojmskcc/prepvi:3.7.0' }"

    input:
    tuple val(meta), val(vcfs), val(csvs)
    path(mut_file)
    path(pty_file)



    output:
    tuple val(meta), path("*._PRE_PyCloneVI_INN.tsv"), emit: tsv
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.patient}"
    def samples = task.ext.prefix ?: "${meta.samples}"
    """
    mkdir VCF/ CSV
    cp ${vcfs} VCF/
    cp ${csvs} CSV/

    prepvi \\
        --dnlt . \\
        --dir_csv CSV/ \\
        --dir_cnv VFC/ \\
        --patient ${prefix}   \\
        --samples ${samples}  \\
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
