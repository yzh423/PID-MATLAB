%EXPORT_REPORT_EVIDENCE Export verified results for the report builder.
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
if ~exist("reportOutputRoot","var")
    reportOutputRoot = fullfile(projectRoot,"results","report");
end
if ~isfolder(reportOutputRoot)
    mkdir(reportOutputRoot);
end
evidence = rrm.report.exportEvidence(projectRoot, ...
    fullfile(reportOutputRoot,"report_evidence.json"));
fprintf("Report evidence schema %d exported with %d stochastic trials.\n", ...
    evidence.schemaVersion,evidence.stochastic.trialCount);
