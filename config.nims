--mm: orc
--deepcopy: on
when not (defined(release) or defined(danger)):
    --lineDir: on
    --lineTrace: on
    --profiler: on
    --stackTrace: on
    --sinkInference: on
