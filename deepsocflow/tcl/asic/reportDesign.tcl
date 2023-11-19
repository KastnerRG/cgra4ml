

verifyGeometry
verifyConnectivity

# Timing report
report_timing -max_paths 100 > ../reports/${design}.post_route.timing.rpt

# Power report
report_power -outfile ../reports/${design}.post_route.power.rpt

# Design report
summaryReport -nohtml -outfile ../reports/${design}.post_route.summary.rpt
