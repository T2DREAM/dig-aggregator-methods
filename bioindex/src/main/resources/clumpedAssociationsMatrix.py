import argparse

from pyspark.sql import SparkSession, DataFrame


def main():
    """
    Arguments: none
    """
    spark = SparkSession.builder.appName('bioindex').getOrCreate()

    # load and output directory
    srcdir = 's3://dig-analysis-data/out/metaanalysis'
    common_dir = 's3://dig-analysis-data/out/varianteffect/common'
    outdir = 's3://dig-bio-index/associations/matrix'

    # load the top association clumps
    clumps = spark.read.json(f'{srcdir}/clumped/*/part-*')
    common = spark.read.json(f'{common_dir}/part-*')

    # load associations across all phenotypes
    assocs = spark.read.json(f'{srcdir}/trans-ethnic/*/part-*')
    assocs = assocs.filter(assocs.pValue <= 0.05)

    # drop the existing association and common fields to prevent duplication
    df = clumps.select(
        clumps.phenotype.alias('leadPhenotype'),
        clumps.clump,
        clumps.varId,
        clumps.alignment,
    )

    # join to build the associations matrix
    df = df.join(assocs, on='varId', how='inner')
    df = df.filter(df.phenotype != df.leadPhenotype)

    # per clump, keep only the best association per phenotype
    df = df.orderBy(['leadPhenotype', 'clump', 'phenotype', 'pValue'])
    df = df.dropDuplicates(['leadPhenotype', 'clump', 'phenotype'])

    # rejoin with the common data
    df = df.join(common, on='varId', how='left_outer')

    # write it out, sorted by the lead phenotype and secondary phenotype
    df.orderBy(['leadPhenotype', 'phenotype']) \
        .write \
        .mode('overwrite') \
        .json(outdir)

    # done
    spark.stop()


if __name__ == '__main__':
    main()
