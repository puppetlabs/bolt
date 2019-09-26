<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2017 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
  <xsl:import href="plugin:org.dita.base:xsl/preprocess/conrefImpl.xsl"/>
  <dita:extension id="dita.xsl.conref" behavior="org.dita.dost.platform.ImportXSLAction" xmlns:dita="http://dita-ot.sourceforge.net"/>
  <xsl:output method="xml" encoding="utf-8" indent="no" />
  
  <xsl:template match="*[@conref and contains(@class, ' topic/')]">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>
