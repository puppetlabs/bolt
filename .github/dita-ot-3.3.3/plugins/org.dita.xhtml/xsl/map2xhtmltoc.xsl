<?xml version="1.0" encoding="UTF-8" ?>

<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2007 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<!-- Map to XHTML -->
<xsl:stylesheet version="2.0"

  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!--main map to xhtml converter-->
<xsl:import href="plugin:org.dita.xhtml:xsl/map2htmltoc.xsl"/>


<xsl:output method="xhtml" encoding="UTF-8"
  indent="no"
  doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
  doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

  <xsl:include href="plugin:org.dita.xhtml:xsl/dita2xhtml-util.xsl"/>

</xsl:stylesheet>