<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2012 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:rx="http://www.renderx.com/XSL/Extensions"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0" exclude-result-prefixes="dita-ot xs">
    
  <xsl:template name="createMetadata">
    <rx:meta-info>
      <xsl:variable name="title" as="xs:string?">
        <xsl:apply-templates select="." mode="dita-ot:title-metadata"/>
      </xsl:variable>
      <xsl:if test="exists($title)">
        <rx:meta-field name="title" value="{$title}"/>
      </xsl:if>
      <xsl:variable name="author" as="xs:string?">
        <xsl:apply-templates select="." mode="dita-ot:author-metadata"/>
      </xsl:variable>
      <xsl:if test="exists($author)">
        <rx:meta-field name="author" value="{$author}"/>
      </xsl:if>
      <xsl:variable name="keywords" as="xs:string*">
        <xsl:apply-templates select="." mode="dita-ot:keywords-metadata"/>
      </xsl:variable>
      <xsl:if test="exists($keywords)">
        <rx:meta-field name="keywords">
          <xsl:attribute name="value" select="$keywords" separator=", "/>
        </rx:meta-field>
      </xsl:if>
      <xsl:variable name="subject" as="xs:string?">
        <xsl:apply-templates select="." mode="dita-ot:subject-metadata"/>
      </xsl:variable>
      <xsl:if test="exists($subject)">
        <rx:meta-field name="subject" value="{$subject}"/>
      </xsl:if>
      <rx:meta-field name="creator" value="DITA Open Toolkit"/>
    </rx:meta-info>
  </xsl:template>

</xsl:stylesheet>
