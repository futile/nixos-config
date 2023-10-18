// for metals
Global / semanticdbEnabled := true

// configure sbt-errorsummary globally
// https://github.com/Duhemm/sbt-errors-summary#configuration
import sbt.errorssummary.Plugin.autoImport._

reporterConfig := reporterConfig.value
  .withReverseOrder(true) // show first error at bottom
