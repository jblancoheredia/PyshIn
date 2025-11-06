process PREPVI {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/prepvi:3.7.0':
        'blancojmskcc/prepvi:3.7.0' }"

    input:
    tuple val(meta), path(vcfs), path(csvs)
    val(samples_mode)
    path(mut_file)
    path(pty_file)

    output:
    tuple val(meta), path("*_PyCloneVI_INN.tsv"), emit: tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    rm .command.trace || true

    mkdir VCF CSV

    mkdir VCF/${prefix}

    mkdir CSV/${prefix}

    cp ${vcfs} VCF/${prefix}/

    cp ${csvs} CSV/${prefix}/

    mkdir .mplconfig

    export MPLCONFIGDIR=".mplconfig"

    prepvi \\
        --dnlt . \\
        --dir_csv CSV/ \\
        --dir_cnv VCF/ \\
        --patient ${prefix} \\
        --dir_mut ${mut_file} \\
        --dir_purity ${pty_file} \\
        --max_workers ${task.cpus} \\
        --samples_mode ${samples_mode} \\
        ${args}

    mv ${prefix}/${prefix}_PyCloneVI_INN.tsv . || exit 1
    test -f ${prefix}_PyCloneVI_INN.tsv || exit 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi: "3.7.0"
    END_VERSIONS
    """
    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_PyCloneVI_INN.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi: "3.7.0"
    END_VERSIONS
    """
}
