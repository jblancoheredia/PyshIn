process PREPVI {
    tag "$patient_id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/prepvi:3.7.0':
        'blancojmskcc/prepvi:3.7.0' }"

    input:
    tuple val(patient_id), val(metas), val(vcfs), val(csvs)
    path(mut_file)
    path(pty_file)



    output:
    tuple val(meta), path("*._PRE_PyCloneVI_INN.tsv"), emit: tsv
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def meta = [ id: patient_id ]
    def prefix = task.ext.prefix ?: "${patient_id}"
    def samples = (metas instanceof List) ? metas.collect{ it.sample_id as String }.join(',') : ''
    def vcf_files = (vcfs instanceof List) ? vcfs.join(' ') : vcfs
    def csv_files = (csvs instanceof List) ? csvs.join(' ') : csvs
    """
    mkdir VCF/ CSV
    cp ${vcf_files} VCF/
    cp ${csv_files} CSV/

    prepvi \\
        --dnlt . \\
        --dir_csv CSV/ \\
        --dir_cnv VCF/ \\
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
    def meta = [ id: patient_id ]
    def prefix = task.ext.prefix ?: "${patient_id}"
    """
    touch ${prefix}_PRE_PyCloneVI_INN.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi: "3.7.0"
    END_VERSIONS
    """
}
