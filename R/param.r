# Save parameters "param" to a file in the "dir" directory
# Save "toplines" first, other parameters next
# Lists and "bamnames" are skipped
parameterDump = function(dir, param, toplines = NULL){
    message("Working in: ",dir);
    .dump = function(fid, param){
        for( nm in names(param) ){ # nm = "modelcovariates"
            pre = "";
            value = param[[nm]];
            if( is.data.frame(value) ){
                txt = paste0("<Data frame ",nrow(value)," x ",ncol(value),">");
                pre = "# ";
            } else if( is.list(value) ){
                txt = paste0("<List of length ", length(value), ">");
                pre = "# ";
            } else if( length(value) > 1 ){
                if(nm == "bamnames"){
                    txt = paste0("<Total ",length(value)," BAM names>");
                    pre = "# ";
                } else {
                    txt = paste0(
                        "c(\n",
                        paste0("  ",sapply(value, deparse),collapse = ",\n"),
                        ")");
                }
            } else {
                txt = deparse(value);
            }
            cat(file = fid, pre, nm, " = ", txt, "\n", sep = "");
            # dput(param[[nm]], file = fid)
        }
    }

    fid = file( paste0(dir, "/UsedSettings.txt"), "wt");
    writeLines(con = fid,
       text = c("## Parameters used to create the files in this directory",""));
    if( !is.null(toplines)){
        .dump(fid, param[toplines[toplines %in% names(param)]]);
        writeLines(con = fid, text = "");
        .dump(fid, param[!(names(param) %in% toplines)]);
    } else {
        .dump(fid, param);
    }
    close(fid);
    return(invisible(NULL));
}

# Scan a file for parameters
parametersFromFile = function( .parameterfile ){
    source(.parameterfile, local = TRUE);
    .nms = ls();
    return(mget(.nms));
}

# Help user set parameters
# via RStudio hint engine
ramwasParameters = function(
    dirproject,
    dirfilter,
    dirrbam,
    dirrqc,
    dirqc,
    dircoveragenorm,
    dirtemp,
    dirpca,
    dirmwas,
    dircv,
    dirbam,
    filebamlist,
    bamnames,
    filebam2sample,
    bam2sample,
    filecpgset,
    filenoncpgset,
    filecovariates,
    covariates,
    cputhreads,
    diskthreads,
    usefilelock,
    scoretag,
    minscore,
    maxrepeats,
    minavgcpgcoverage,
    minnonzerosamples,
    buffersize,
    doublesize,
    modelcovariates,
    modeloutcome,
    modelPCs,
    qqplottitle,
    toppvthreshold,
    mmncpgs,
    mmalpha,
    cvnfolds,
    bihost,
    bimart,
    bidataset,
    biattributes,
    bifilters,
    biflank,
    fileSNPs,
    dirSNPs,
    ...
    ){
    rez = as.list(match.call());
    return(rez);
}

# Transform bam2sample file into a list
parseBam2sample = function( lines ){
    # remove trailing commas, .bam at name ends,
    # spaces around commas and "=", and trailing spaces
    lines = gsub(",$", "",       lines);
    lines = gsub("\\.bam,", ",", lines, ignore.case = TRUE);
    lines = gsub("\\.bam$", "",  lines, ignore.case = TRUE);
    lines = gsub(" $", "",       lines);
    lines = gsub(" ,", ",",      lines, fixed = TRUE);
    lines = gsub(", ", ",",      lines, fixed = TRUE);
    lines = gsub(" =", "=",      lines, fixed = TRUE);
    lines = gsub("= ", "=",      lines, fixed = TRUE);

    split.eq = strsplit(lines, split = "=", fixed = TRUE);
    samplenames = sapply(split.eq, `[`, 1);
    bamlist = strsplit(sapply(split.eq,tail,1), split = ",", fixed = TRUE);
    names(bamlist) = samplenames;

    return(bamlist);
}

# Get parameters from command line, return them in a list
# For "fileparam" parameter - source the file
processCommandLine = function(.arg = NULL){
    if( is.null(.arg))
        .arg=commandArgs(TRUE);
    # .arg = c("fileparam=\"D:/RW/CELL/param_file.txt\"","ext=123123123")
    if( length(.arg)==0 ){
        message("No arguments supplied");
    } else {
        for (.i in seq_along(.arg)){ # .i=1
            fileparam = NULL;
            message("Input parameter: ", .arg[.i]);
            eval(parse(text=.arg[.i]));
            if(!is.null(fileparam)){
                source(fileparam, local = TRUE);
            }
        }
    }
    rm(fileparam);
    return(mget(ls()));
}

# Fill in gaps in the parameter list
# Make paths absolute
parameterPreprocess = function( param ){
    ### Get from a file if param is not a list
    if(is.character(param)){
        param = parametersFromFile(param);
    }

    if(is.null(param$modelhasconstant)) param$modelhasconstant = TRUE;
    
    # Set up directories
    if( is.null(param$dirproject) ) param$dirproject = getwd();
    if(!is.null(param$dirbam))
        param$dirbam = makefullpath(param$dirproject, param$dirbam);

    if( is.null(param$dirfilter) ){
        param$dirfilter = FALSE;
    }
    if( is.logical(param$dirfilter) ){
        if( param$dirfilter ){
            param$dirfilter = paste0( param$dirproject,
                            "/Filter_", param$scoretag, "_", param$minscore);
        } else {
            param$dirfilter = param$dirproject;
        }
    } else {
        param$dirfilter = makefullpath(param$dirproject, param$dirfilter);
    }
    if( is.null(param$dirrbam) )
        param$dirrbam = "rds_rbam";
    param$dirrbam = makefullpath( param$dirfilter, param$dirrbam);
    if( is.null(param$dirrqc) ) param$dirrqc = "rds_qc";
    param$dirrqc = makefullpath( param$dirfilter, param$dirrqc);
    if( is.null(param$dirqc) ) param$dirqc = "qc";
    param$dirqc = makefullpath( param$dirfilter, param$dirqc);

    ### Filter parameters
    if( is.null(param$scoretag) ) param$scoretag = "mapq";
    if( is.null(param$minscore) ) param$minscore = 4;
    if( is.null(param$maxrepeats) ) param$maxrepeats = 3;

    ### More analysis parameters
    if( is.null(param$cputhreads) ) param$cputhreads = detectCores();
    if( is.null(param$diskthreads)) param$diskthreads = min(param$cputhreads,2);

    ### BAM list processing
    if( is.null(param$bamnames) & !is.null(param$filebamlist)){
        param$filebamlist = makefullpath(param$dirproject,param$filebamlist)
        param$bamnames = readLines(param$filebamlist);
    }
    if( !is.null(param$bamnames)){
        param$bamnames = gsub("\\.bam$", "", param$bamnames, ignore.case = TRUE)
    }

    ### CV and MM
    if( is.null(param$cvnfolds) ) param$cvnfolds = 10;
    if( is.null(param$mmalpha) ) param$mmalpha = 0;
    if( is.null(param$mmncpgs) ) param$mmncpgs = 1000;
    stopifnot(all( param$mmncpgs > 1 ))

    ### BAM2sample processing
    if( !is.null(param$filebam2sample) & is.null(param$bam2sample)){
        filename = makefullpath(param$dirproject, param$filebam2sample);
        param$bam2sample = parseBam2sample( readLines(filename) );
        rm(filename);
    }
    if( is.null(param$bam2sample) & !is.null(param$bamnames) ){
        param$bam2sample = basename(param$bamnames);
        names(param$bam2sample) = basename(param$bamnames);
    }
    ### Covariate file
    if( !is.null(param$filecovariates) & is.null(param$covariates)){

        sep = "\t";
        if(grepl("\\.csv$",param$filecovariates))
            sep = ",";
        filename = makefullpath(param$dirproject, param$filecovariates);
        param$covariates = read.table(filename, header = TRUE, sep = sep,
                              stringsAsFactors = FALSE, check.names = FALSE);
        rm(filename);
    }
    if( is.null(param$modelPCs) )
        param$modelPCs = 0;
    if( !is.null(param$covariates)){
        param$covariates[[1]] = as.character(param$covariates[[1]]);
        if( is.null(param$dircoveragenorm) )
            param$dircoveragenorm =
                paste0("coverage_norm_",nrow(param$covariates));
        param$dircoveragenorm =
            makefullpath(param$dirfilter, param$dircoveragenorm);

        if( any(duplicated(param$covariates[[1]])) )
            stop("Repeated samples in the covariate file");

        if( !all(param$modelcovariates %in% names(param$covariates) ) )
            stop( paste("Covariates (modelcovariates) missing in covariates",
             param$modelcovariates[
                 !(param$modelcovariates %in% names(param$covariates)) ]));

        if( !is.null(param$modeloutcome) )
            if( !( param$modeloutcome %in% names(param$covariates)) )
                stop( paste("Model outcome not present in covariate file:",
                            param$modeloutcome));
    } else if( !is.null(param$bam2sample) ){
        if( is.null(param$dircoveragenorm) )
            param$dircoveragenorm =
                paste0("coverage_norm_",length(param$bam2sample));
        param$dircoveragenorm =
            makefullpath(param$dirfilter, param$dircoveragenorm);
    } else {
        if( is.null(param$dircoveragenorm) )
            param$dircoveragenorm = "coverage_norm";
        param$dircoveragenorm =
            makefullpath(param$dirfilter, param$dircoveragenorm);
    }
    
    # SNPs analysis
    if(is.null(param$dirSNPs))
        param$dirSNPs = paste0("Testing_wSNPs_",
                               param$modeloutcome, '_',
                               length(param$modelcovariates), 'cvrts_',
                               param$modelPCs, "PCs");
    param$dirSNPs = makefullpath( param$dircoveragenorm, param$dirSNPs);

    if(!is.null(param$fileSNPs))
        param$fileSNPs = makefullpath( param$dircoveragenorm, param$fileSNPs);
    
    if( is.null(param$dirpca) ){
        if( length(param$modelcovariates) > 0 ){
            # library(digest);
            hash = digest(
                object = paste(sort(param$modelcovariates),
                               collapse = "\t"),
                algo = "crc32", serialize = FALSE);
            param$dirpca = sprintf("PCA_%02d_cvrts_%s",
                                   length(param$modelcovariates), hash);
        } else {
            param$dirpca = "PCA_00_cvrts";
        }
    }
    param$dirpca = makefullpath(param$dircoveragenorm, param$dirpca);
    
    if( is.null(param$dirmwas) )
        param$dirmwas = paste0("Testing_",param$modeloutcome,
                               "_",param$modelPCs,"_PCs");
    param$dirmwas = makefullpath(param$dirpca, param$dirmwas);
    
    if( is.null(param$qqplottitle) ){
        qqplottitle = paste0("Testing ",param$modeloutcome,"\n",
                             param$modelPCs," PC",
                             if(param$modelPCs!=1)"s"else"");
        if(length(param$modelcovariates)>0)
            qqplottitle = paste0(
                qqplottitle, " and ",
                length(param$modelcovariates)," covariate",
                if(length(param$modelcovariates)!=1)"s:\n"else": ",
                paste0(param$modelcovariates,collapse = ", "))
        param$qqplottitle = qqplottitle;
        rm(qqplottitle);
    }
    if( is.null(param$dircv) )
        param$dircv = sprintf("%s/CV_%02d_folds",
                              param$dirmwas, param$cvnfolds);
    
    if( is.null(param$dirtemp) ) param$dirtemp = "temp";
    param$dirtemp = makefullpath(param$dircoveragenorm, param$dirtemp );

    ### CpG set should exist
    if( !is.null(param$filecpgset) ){
        param$filecpgset =
            makefullpath(param$dirproject, param$filecpgset);
        stopifnot( file.exists(param$filecpgset) );
    }
    if( !is.null(param$filenoncpgset) ){
        param$filenoncpgset =
            makefullpath(param$dirproject, param$filenoncpgset);
        stopifnot( file.exists(param$filenoncpgset) );
    }

    if( is.null(param$doublesize) ) param$doublesize = 4;
    if( is.null(param$recalculate.QCs) ) param$recalculate.QCs = FALSE;
    if( is.null(param$buffersize) ) param$buffersize = 1e9;

    if( is.null(param$minavgcpgcoverage) ) param$minavgcpgcoverage = 0.3;
    if( is.null(param$minnonzerosamples) ) param$minnonzerosamples = 0.3;

    if( is.null(param$usefilelock) ) param$usefilelock = FALSE;

    if( is.null(param$randseed) ) param$randseed = 18090212;
    # Famous person date of birth: February 12, 1809

    if( is.null(param$toppvthreshold) ) param$toppvthreshold = 50;

    # BioInformatics paramters

    if( is.null(param$bihost) ) param$bihost = "grch37.ensembl.org";
    if( is.null(param$bimart) ) param$bimart = "ENSEMBL_MART_ENSEMBL";

    # listDatasets(useMart(param$bimart))
    if( is.null(param$bidataset) ){
        param$bidataset = "hsapiens_gene_ensembl";

        # listAttributes(useMart(biomart=param$bimart, dataset=param$bidataset))
        if( is.null(param$biattributes) )
            param$biattributes = c("hgnc_symbol","entrezgene","strand");

        if( is.null(param$bifilters) )
            param$bifilters = list(with_hgnc_transcript_name=TRUE);

        if( is.null(param$biflank) )
            param$biflank = 0;
    }

    return(param);
}
