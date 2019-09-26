<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2018 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:opentopic="http://www.idiominc.com/opentopic"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                xmlns:svg="http://www.w3.org/2000/svg"
                version="2.0"
                exclude-result-prefixes="xs opentopic dita-ot ditamsg">

  <xsl:template match="*[contains(@class,' svg-d/svgref ')]">
    <xsl:call-template name="image"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' svg-d/svg-container ')]">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="svg:svg">
    <fo:instream-foreign-object>
      <xsl:copy-of select="."/>
    </fo:instream-foreign-object>
  </xsl:template>

</xsl:stylesheet>
