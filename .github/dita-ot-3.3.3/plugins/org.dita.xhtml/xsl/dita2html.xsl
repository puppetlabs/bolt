<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<!-- ereview.xsl
 | DITA topic to HTML for ereview & webreview

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

<!-- stylesheet imports -->
<!-- the main dita to xhtml converter -->
<xsl:import href="plugin:org.dita.xhtml:xsl/dita2html-base.xsl"/>

<xsl:output method="html"
            encoding="UTF-8"
            indent="no"
            doctype-system="http://www.w3.org/TR/html4/loose.dtd"
            doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"
/>

  <!-- Set the A-NAME attr for NS -->
  <xsl:template name="setanametag">
    <xsl:param name="idvalue"/>
    <a>
      <xsl:attribute name="name">
        <xsl:if test="ancestor::*[contains(@class,' topic/body ')]">
          <xsl:value-of select="ancestor::*[contains(@class,' topic/body ')]/parent::*/@id"/><xsl:text>__</xsl:text>
        </xsl:if>
        <xsl:value-of select="$idvalue"/>
      </xsl:attribute>
      <xsl:value-of select="$afill"/><xsl:comment><xsl:text> </xsl:text></xsl:comment> <!-- fix for home page reader -->
    </a>
  </xsl:template>  

</xsl:stylesheet>
