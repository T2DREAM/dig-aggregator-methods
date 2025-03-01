package org.broadinstitute.dig.aggregator.methods.bioindex

import org.broadinstitute.dig.aggregator.core._
import org.broadinstitute.dig.aws._
import org.broadinstitute.dig.aws.config.emr._
import org.broadinstitute.dig.aws.emr._

/** The final result of all aggregator methods is building the BioIndex. All
  * outputs are to the dig-bio-index bucket in S3.
  */
class GeneAssociationsStage(implicit context: Context) extends Stage {
  val magma   = Input.Source.Success("out/magma/gene-associations/*/")
  val t2d_52k = Input.Source.Dataset("gene_associations/52k_T2D/*/")
  val qt_52k  = Input.Source.Dataset("gene_associations/52k_QT/*/")

  /** Input sources. */
  override val sources: Seq[Input.Source] = Seq(magma, t2d_52k, qt_52k)

  /** Rules for mapping input to outputs. */
  override val rules: PartialFunction[Input, Outputs] = {
    case t2d_52k(phenotype) => Outputs.Named("52k")
    case qt_52k(phenotype)  => Outputs.Named("52k")
    case magma(phenotype)   => Outputs.Named("magma")
  }

  /** Use latest EMR release. */
  override val cluster: ClusterDef = super.cluster.copy(
    releaseLabel = ReleaseLabel.emrLatest
  )

  /** Output to Job steps. */
  override def make(output: String): Job = {
    val script = resourceUri("geneAssociations.py")

    val step = output match {
      case "52k"   => Job.PySpark(script, "--52k")
      case "magma" => Job.PySpark(script, "--magma")
    }

    new Job(Seq(step))
  }
}
