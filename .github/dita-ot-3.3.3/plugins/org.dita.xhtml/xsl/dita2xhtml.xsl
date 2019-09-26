<?xml version="1.0" encoding="utf-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2011 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <xsl:import href="plugin:org.dita.xhtml:xsl/dita2html-base.xsl"/>
  
  <xsl:output method="xhtml"
              encoding="UTF-8"
              indent="no"
              doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
              doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
 
  <xsl:include href="plugin:org.dita.xhtml:xsl/dita2xhtml-util.xsl"/>
  
  <!-- Add both lang and xml:lang attributes -->
  <xsl:template match="@xml:lang" name="generate-lang">
    <xsl:param name="lang" select="."/>
    <xsl:attribute name="xml:lang">
      <xsl:value-of select="$lang"/>
    </xsl:attribute>
    <xsl:attribute name="lang">
      <xsl:value-of select="$lang"/>
    </xsl:attribute>
  </xsl:template>


</xsl:stylesheet>
