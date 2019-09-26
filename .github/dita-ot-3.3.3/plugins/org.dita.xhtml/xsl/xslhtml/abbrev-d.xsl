<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
     xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
     exclude-result-prefixes="ditamsg dita-ot">

<!-- KEYREF-FILE is defined in dita2htmlImpl.xsl: -->
<!--<xsl:param name="KEYREF-FILE" select="concat($WORKDIR,$PATH2PROJ,'keydef.xml')"/>-->

<xsl:template match="*[contains(@class,' abbrev-d/abbreviated-form ')]" name="topic.abbreviated-form">
  <xsl:if test="@keyref and @href">
    <xsl:variable name="entry-file-contents" as="node()*"
      select="dita-ot:retrieve-href-target(@href)"/>
    <xsl:choose>
      <xsl:when test="$entry-file-contents/descendant-or-self::*[contains(@class,' glossentry/glossentry ')]">
        <!-- Fall back to process with normal term rules -->
        <xsl:call-template name="topic.term"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- TODO: Throw a warning for incorrect usage of <abbreviated-form> -->
        <xsl:apply-templates select="." mode="ditamsg:no-glossentry-for-abbreviated-form">
          <xsl:with-param name="keys" select="@keyref"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<xsl:template match="*" mode="ditamsg:no-glossentry-for-abbreviated-form">
  <xsl:param name="keys"/>
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX060W'"/>
    <xsl:with-param name="msgparams">%1=<xsl:value-of select="$keys"/></xsl:with-param>
  </xsl:call-template>
</xsl:template>

</xsl:stylesheet>
