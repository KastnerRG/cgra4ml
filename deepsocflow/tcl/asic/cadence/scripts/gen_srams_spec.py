#!/usr/bin/env python3
"""
Generate a Samsung SRAM compiler .spec file with parameterized values.

Usage:
    # Dual-port (2p):
    python gen_srams_spec.py --sram_type 2p --instname rf_2p_hsc --libname rf_2p_hsc \
        --bits 32 --words 32 --mux 1 --output rf_2p_hsc.spec

    # Single-port (sp):
    python gen_srams_spec.py --sram_type sp --instname rf_sp_hse --libname rf_sp_hse \
        --bits 32 --words 1024 --mux 4 --output rf_sp_hse.spec
"""

import argparse

CORNERS = (
    "ffpg_sigcmin_0p605v_0p825v_125c,ffpg_sigcmin_0p605v_0p825v_m40c,"
    "ffpg_sigcmin_0p715v_0p825v_125c,ffpg_sigcmin_0p715v_0p825v_m40c,"
    "ffpg_sigcmin_0p825v_0p825v_125c,ffpg_sigcmin_0p825v_0p825v_m40c,"
    "ffpg_sigcmin_0p90v_0p90v_125c,ffpg_sigcmin_0p90v_0p90v_m40c,"
    "ffpg_sigcmin_1p00v_1p00v_125c,ffpg_sigcmin_1p00v_1p00v_m40c,"
    "fsg_sigrcmax_0p585v_0p675v_m40c,fsg_sigrcmax_0p675v_0p675v_m40c,"
    "fsg_sigrcmax_0p765v_0p765v_m40c,"
    "sfg_sigrcmax_0p585v_0p675v_m40c,sfg_sigrcmax_0p675v_0p675v_m40c,"
    "sfg_sigrcmax_0p765v_0p765v_m40c,"
    "sspg_sigrcmax_0p495v_0p675v_125c,sspg_sigrcmax_0p495v_0p675v_m40c,"
    "sspg_sigrcmax_0p585v_0p675v_125c,sspg_sigrcmax_0p585v_0p675v_m40c,"
    "sspg_sigrcmax_0p675v_0p675v_125c,sspg_sigrcmax_0p675v_0p675v_m40c,"
    "sspg_sigrcmax_0p765v_0p765v_125c,sspg_sigrcmax_0p765v_0p765v_m40c,"
    "sspg_sigrcmax_0p855v_0p855v_125c,sspg_sigrcmax_0p855v_0p855v_m40c,"
    "tt_nominal_0p55v_0p75v_85c,tt_nominal_0p65v_0p75v_125c,"
    "tt_nominal_0p65v_0p75v_85c,tt_nominal_0p75v_0p75v_125c,"
    "tt_nominal_0p75v_0p75v_25c,tt_nominal_0p75v_0p75v_85c,"
    "tt_nominal_0p85v_0p85v_125c,tt_nominal_0p85v_0p85v_85c,"
    "tt_nominal_0p95v_0p95v_125c,tt_nominal_0p95v_0p95v_85c"
)

# Fields present in both 2p and sp specs with the same fixed values
_COMMON = {
    "EOL_guardband":      "0",
    "PG_PINS_domain":     "VDDCE",
    "activity_factor":    "50",
    "atf":                "off",
    "automotive_scan":    "off",
    "back_biasing":       "off",
    "bisr":               "off",
    "bistmux":            "off",
    "bmux":               "off",
    "bus_notation":       "on",
    "check_instname":     "on",
    "corners":            CORNERS,
    "cpf_rtl_gen":        "0",
    "credundancy":        "off",
    "credundancy_enable": "off",
    "ctlviewstyle":       "scan",
    "cust_comment":       "",
    "diodes":             "on",
    "drive":              "6",
    "dual_rail":          "on",
    "ema":                "on",
    "fci_type":           "not_fci",
    "flexible_banking":   "1",
    "fra_enable":         "off",
    "full_pg":            "on",
    "left_bus_delim":     "[",
    "leftright_enable":   "off",
    "libertyviewstyle":   "nldm",
    "lren_width":         "2",
    "metal_stack":        "",
    "mvt":                "LP",
    "name_case":          "upper",
    "pipeline":           "off",
    "power_gates":        "header",
    "power_gating":       "off",
    "power_type":         "otc",
    "prefix":             "",
    "pwr_gnd_rename":     "vddpe:VDDSOCE,vddce:VDDCE,vsse:VSSE",
    "ra":                 "on",
    "rcols":              "2",
    "redundancy":         "off",
    "retention":          "on",
    "right_bus_delim":    "]",
    "rre_enable":         "off",
    "rredundancy":        "off",
    "rrows":              "0",
    "rrows2_enable":      "off",
    "scan":               "off",
    "ser":                "none",
    "site_def":           "off",
    "top_layer":          "m6-m14",
    "use_dump_for_lef":   "0",
    "vmin_assist":        "on",
    "wa":                 "off",
    "wp_size":            "1",
}

# Fields exclusive to the dual-port (2p) spec
_2P_ONLY = {
    "bit_incr":       "4",
    "datatable_mode": "on",
    "enable_ia":      "off",
}

# Fields exclusive to the single-port (sp) spec
_SP_ONLY = {
    "bit_incr":         "1",
    "compiler_type":    "sp",
    "early_enable":     "off",
    "eva_enable":       "off",
    "fcicell":          "off",
    "flex_slice1":      "off",
    "flexible_bitline": "off",
    "flexible_slice":   "2",
    "late_cancel":      "off",
    "lren4_enable":     "off",
    "power_gating_sub": "full_pg",
    "rebuf_force":      "off",
    "rows_p_bl":        "256",
    "scan_type":        "full",
}

_DEFAULT_COMPILER = {
    "2p": "rf_2p_hsc_svt_mvt",
    "sp": "rf_sp_hse_svt_mvt",
}


def generate_spec(
    instname,
    libname,
    bits,
    words,
    mux,
    sram_type="2p",
    compiler=None,
    frequency=1.0,
    write_mask="off",
    output_file=None,
):
    if sram_type not in ("2p", "sp"):
        raise ValueError(f"sram_type must be '2p' or 'sp', got '{sram_type}'")

    if compiler is None:
        compiler = _DEFAULT_COMPILER[sram_type]

    params = dict(_COMMON)

    if sram_type == "2p":
        params.update(_2P_ONLY)
    else:
        params.update(_SP_ONLY)
        params["dest_lib_name"] = f"{compiler}_mpa"

    # Apply parameterized values (override defaults)
    params.update({
        "bits":       str(bits),
        "frequency":  str(frequency),
        "instname":   instname,
        "libname":    libname,
        "mux":        str(mux),
        "words":      str(words),
        "write_mask": write_mask,
    })

    lines = [f"# user spec file, compiler {compiler}", ""]
    for key in sorted(params.keys()):
        lines.append(f"{key} = {params[key]}")
    content = "\n".join(lines) + "\n"

    if output_file:
        with open(output_file, "w") as f:
            f.write(content)
        print(f"Written: {output_file}")
    else:
        print(content)

    return content


def main():
    parser = argparse.ArgumentParser(
        description="Generate Samsung SRAM compiler .spec file"
    )
    parser.add_argument("--sram_type",  default="2p", choices=["2p", "sp"],
                        help="SRAM port type: '2p' dual-port or 'sp' single-port (default: 2p)")
    parser.add_argument("--instname",   required=True,
                        help="Instance name (e.g. rf_2p_hsc)")
    parser.add_argument("--libname",    required=True,
                        help="Library name (e.g. rf_2p_hsc)")
    parser.add_argument("--bits",       required=True, type=int,
                        help="Data width in bits")
    parser.add_argument("--words",      required=True, type=int,
                        help="Number of words (depth)")
    parser.add_argument("--mux",        required=True, type=int,
                        help="Column mux factor")
    parser.add_argument("--compiler",   default=None,
                        help="Compiler name for header comment (auto-derived if omitted)")
    parser.add_argument("--frequency",  default=1.0, type=float,
                        help="Target frequency in GHz (default: 1.0)")
    parser.add_argument("--write_mask", default="off", choices=["on", "off"],
                        help="Write mask enable (default: off)")
    parser.add_argument("--output",     required=True,
                        help="Output .spec file path")
    args = parser.parse_args()

    generate_spec(
        instname=args.instname,
        libname=args.libname,
        bits=args.bits,
        words=args.words,
        mux=args.mux,
        sram_type=args.sram_type,
        compiler=args.compiler,
        frequency=args.frequency,
        write_mask=args.write_mask,
        output_file=args.output,
    )


if __name__ == "__main__":
    main()
