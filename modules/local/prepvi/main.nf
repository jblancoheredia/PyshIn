process PREPVI {
    tag "$patient_id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://blancojmskcc/prepvi:3.7.0':
        'blancojmskcc/prepvi:3.7.0' }"

    input:
    tuple val(patient_id), val(metas), val(vcfs), val(csvs)
    val(samples_mode)
    path(mut_file)
    path(pty_file)

    def meta            = [ id: "${patient_id}", patient: "${patient_id}" ]

    output:
    tuple val(meta), path("*_PyCloneVI_INN.tsv"), emit: tsv
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args            = task.ext.args ?: ''
    def patient_id_val  = patient_id.toString()
    def prefix          = task.ext.prefix ?: "${patient_id}"
    def samples         = metas.collect { it.sample_id }.join(',')
    def csv_files       = (csvs instanceof List) ? csvs.join(' ') : csvs
    def vcf_files       = (vcfs instanceof List) ? vcfs.join(' ') : vcfs

    """
    rm .command.trace
    mkdir VCF/ CSV
    mkdir VCF/${prefix}/
    mkdir CSV/${prefix}/
    cp ${vcf_files} VCF/${prefix}/
    cp ${csv_files} CSV/${prefix}/

    mkdir -p .mplconfig
    export MPLCONFIGDIR="\$PWD/.mplconfig"

    prepvi \\
        --dnlt . \\
        --dir_csv CSV/ \\
        --dir_cnv VCF/  \\
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
    def args = task.ext.args ?: ''
    def patient_id_val = patient_id.toString()
    def meta = [ id: patient_id_val, patient: patient_id_val ]
    def prefix = task.ext.prefix ?: "${patient_id}"
    """
    touch ${prefix}_PyCloneVI_INN.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        prepvi: "3.7.0"
    END_VERSIONS
    """
}
