<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2014 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0"
                exclude-result-prefixes="xs dita-ot">

  <xsl:import href="plugin:org.dita.xhtml:xsl/map2htmtoc/map2htmlImpl.xsl"/>
  <xsl:import href="plugin:org.dita.xhtml:xsl/map2htmtoc/map2htmlcoverImpl.xsl"/>

  <dita:extension id="dita.xsl.html.cover" behavior="org.dita.dost.platform.ImportXSLAction" xmlns:dita="http://dita-ot.sourceforge.net"/>

</xsl:stylesheet>
