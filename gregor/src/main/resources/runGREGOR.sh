#!/bin/bash -xe
#
# usage: runGREGOR.sh <ancestry> [r2]
#           where
#               ancestry       = "AFR" | "AMR" | "ASN" | "EUR" | "SAN"
#               r2             = "0.2" | "0.7"
#               phenotype      = "T2D" | "FI" | ...
#               t2dkp_ancestry = "AA" | "HS" | "EA" | "EU" | "SA"
#

ANCESTRY=$1
R2=$2
PHENOTYPE=$3
T2DKP_ANCESTRY=$4

# where GREGOR is installed locally
GREGOR_ROOT=/mnt/var/gregor
STEP_ROOT=$(pwd)

# root location in S3
S3_DIR="s3://dig-analysis-data/out/gregor"

# various files and directories for the configuration
BED_INDEX_FILE="${GREGOR_ROOT}/bed.file.index"
REF_DIR="${GREGOR_ROOT}/ref"
CONFIG_FILE="${STEP_ROOT}/config.txt"
SNP_FILE="${STEP_ROOT}/snplist.txt"
OUT_DIR="${STEP_ROOT}/out"
SUMMARY_DIR="${S3_DIR}/summary/${PHENOTYPE}/ancestry=${T2DKP_ANCESTRY}"

# delete whatever data was previously created
aws s3 rm "${SUMMARY_DIR}/" --recursive

# source location of SNP part files
SNPS="${S3_DIR}/snp/${PHENOTYPE}/ancestry=${T2DKP_ANCESTRY}/part-*"

# if there are no snps, then don't try and run
if ! hadoop fs -test -e "${SNPS}"; then
    exit 0
fi

# download the SNP parts into a single file
hadoop fs -getmerge -skip-empty-file "${SNPS}" "${SNP_FILE}"

# write the configuration file for GREGOR
cat > "${CONFIG_FILE}" <<EOF
INDEX_SNP_FILE      = ${SNP_FILE}
BED_FILE_INDEX      = ${BED_INDEX_FILE}
REF_DIR             = ${REF_DIR}
POPULATION          = ${ANCESTRY}
R2THRESHOLD         = ${R2}
OUT_DIR             = ${OUT_DIR}
LDWINDOWSIZE        = 1
MIN_NEIGHBOR_NUM    = 500
BEDFILE_IS_SORTED   = True
TOPNBEDFILES        = 2
JOBNUMBER           = 10
BATCHTYPE           = local
EOF

# for debugging, dump the config file to STDOUT...
cat "${CONFIG_FILE}"

# run GREGOR
cd "${GREGOR_ROOT}/GREGOR/script"
perl GREGOR.pl --conf "${CONFIG_FILE}"

# dump the GREGOR.log file to STDOUT so it's in the log
if [[ -e "${OUT_DIR}/GREGOR.log" ]]; then
    cat "${OUT_DIR}/GREGOR.log"
fi

# upload output back to S3
aws s3 cp "${OUT_DIR}/StatisticSummaryFile.txt" "${SUMMARY_DIR}/statistics.txt"
