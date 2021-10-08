//
// This file holds several functions specific to the workflow/tyche.nf in the nf-core/tyche pipeline
//

class WorkflowTyche {

    public static Map parseSubSampleParameters(params) {
        def result = [:]
        result.genome_size = params.genome_size ? params.genome_size.split(',') : []
        result.coverage = params.coverage ? params.coverage.split(',') : []
        result.bases = params.bases ? params.bases.split(',') : []
        result.reads_num = params.reads_num ? params.reads_num.split(',').collect { it.toInteger() } : []
        result.seeds = params.seeds.split(',').collect { it.toInteger() }.unique()
        result.replicates = params.replicates.toInteger()
        return result
    }

    //
    // Check and validate parameters
    //
    public static void initialise(params, log) {
        // genomeExistsError(params, log)

    // if (!params.fasta) {
    // log.error "Genome fasta file not specified with e.g. '--fasta genome.fa' or via a detectable config file."
    // System.exit(1)
    // }

        if (!((params.genome_size && params.coverage) || params.bases || params.reads_num)) {
            log.error 'You *must* specify either both the desired --coverage and --genome_size, the number of --bases, or the --reads_num to be sampled.'
            System.exit(2)
        }
        // Validate and convert sample size parameters.
        if (params.genome_size || params.coverage) {
            if (params.genome_size.split(',').size() != params.coverage.split(',').size()) {
                log.error 'The same number of comma-separated --genome_size and --coverage *must* be specified.'
                System.exit(2)
            }
            WorkflowTyche.checkSizeParameter(params.bases, log)
            WorkflowTyche.checkSizeParameter(params.reads_num, log)
        }
        if (params.bases) {
            WorkflowTyche.checkSizeParameter(params.genome_size || params.coverage, log)
            WorkflowTyche.checkSizeParameter(params.reads_num, log)
        }
        if (params.reads_num) {
            params.reads_num = params.reads_num.split(',')
                .collect { it.toInteger() }
            WorkflowTyche.checkSizeParameter(params.genome_size || params.coverage, log)
            WorkflowTyche.checkSizeParameter(params.bases, log)
        }
        // Convert and implicitly validate seeds parameter.
        params.seeds = params.seeds.split(',')
            .collect { it.toInteger() }
            .unique()
    }

    private static void checkSizeParameter(Boolean value, log) {
        if (value) {
            log.error 'You *must* specify only one of the size options.'
            System.exit(2)
        }
    }

    //
    // Get workflow summary for MultiQC
    //
    public static String paramsSummaryMultiqc(workflow, summary) {
        String summary_section = ''
        for (group in summary.keySet()) {
            def group_params = summary.get(group)  // This gets the parameters of that particular group
            if (group_params) {
                summary_section += "    <p style=\"font-size:110%\"><b>$group</b></p>\n"
                summary_section += "    <dl class=\"dl-horizontal\">\n"
                for (param in group_params.keySet()) {
                    summary_section += "        <dt>$param</dt><dd><samp>${group_params.get(param) ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>\n"
                }
                summary_section += '    </dl>\n'
            }
        }

        String yaml_file_text  = "id: '${workflow.manifest.name.replace('/', '-')}-summary'\n"
        yaml_file_text        += "description: ' - this information is collected when the pipeline is started.'\n"
        yaml_file_text        += "section_name: '${workflow.manifest.name} Workflow Summary'\n"
        yaml_file_text        += "section_href: 'https://github.com/${workflow.manifest.name}'\n"
        yaml_file_text        += "plot_type: 'html'\n"
        yaml_file_text        += 'data: |\n'
        yaml_file_text        += "${summary_section}"
        return yaml_file_text
    }

    //
    // Exit pipeline if incorrect --genome key provided
    //
    private static void genomeExistsError(params, log) {
        if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
            log.error '=============================================================================\n' +
                "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" +
                '  Currently, the available genome keys are:\n' +
                "  ${params.genomes.keySet().join(', ')}\n" +
                '==================================================================================='
            System.exit(1)
        }
    }

}
