<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2011 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
  xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  version="2.0"
  exclude-result-prefixes="opentopic-index opentopic-func xs">

  <xsl:variable name="index.continued-enabled" select="false()"/>

  <xsl:variable name="UNIQUE_INFIX" select="'_unique_'" as="xs:string"/>

  <xsl:function name="opentopic-func:get-unique-refid-value" as="xs:string">
    <xsl:param name="el" as="element(opentopic-index:refID)"/>

    <xsl:sequence
      select="concat($el/@value, $UNIQUE_INFIX, generate-id($el))"/>
  </xsl:function>

  <xsl:key name="refid-by-value" use="@value" match="opentopic-index:refID"/>

  <xsl:key name="refid-by-end-range-value"
    use="ancestor-or-self::opentopic-index:index.entry[@end-range]/@value"
    match="opentopic-index:refID[empty(ancestor::opentopic-index:index.groups)]"/>

  <xsl:template match="opentopic-index:index.entry[opentopic-index:refID/@value]">
    <!--Insert simple index entry marker-->
    <xsl:apply-templates
      select="opentopic-index:refID[last()]" mode="make-wrapper"/>

    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="opentopic-index:refID" mode="make-wrapper">
    <fo:wrapper id="{opentopic-func:get-unique-refid-value(.)}"/>
  </xsl:template>

  <xsl:template match="opentopic-index:index.entry" mode="make-index-ref">
    <xsl:param name="idxs" as="element(opentopic-index:refID)*"/>
    <xsl:param name="inner-text" as="element(opentopic-index:formatted-value)*"/>
    <xsl:param name="no-page"/>

    <fo:block id="{generate-id()}" xsl:use-attribute-sets="index.term">
      <xsl:if test="empty(preceding-sibling::opentopic-index:index.entry)">
        <xsl:attribute name="keep-with-previous">always</xsl:attribute>
      </xsl:if>

      <fo:inline>
        <xsl:apply-templates select="$inner-text/node()"/>
      </fo:inline>

      <xsl:if test="not($no-page) and exists($idxs)">
        <xsl:sequence select="$index.separator"/>

        <xsl:variable name="links" as="element()*">
          <xsl:for-each select="$idxs">
            <xsl:apply-templates mode="make-index-links"
              select="key('refid-by-value', @value)
                      [empty(ancestor-or-self::opentopic-index:index.entry[@end-range])]
                      [empty(ancestor::opentopic-index:index.groups)]
                      [empty(ancestor::*[@no-page eq 'true'])]
                      [ancestor::*[contains(@class,' topic/topic ')]]"/>
          </xsl:for-each>
        </xsl:variable>

        <xsl:for-each select="$links">
          <xsl:if test="not(position() eq 1)">
            <xsl:text>, </xsl:text>
          </xsl:if>
          <xsl:sequence select="."/>
        </xsl:for-each>
      </xsl:if>

      <xsl:if test="@no-page eq 'true'">
        <xsl:apply-templates select="opentopic-index:see-childs" mode="index-postprocess"/>
      </xsl:if>

      <xsl:if test="empty(opentopic-index:index.entry)">
        <xsl:apply-templates select="opentopic-index:see-also-childs" mode="index-postprocess"/>
      </xsl:if>
    </fo:block>
  </xsl:template>

  <xsl:template match="opentopic-index:refID" mode="make-index-links">
    <xsl:variable name="value" as="xs:string"
      select="opentopic-func:get-unique-refid-value(.)"/>

    <fo:basic-link internal-destination="{$value}" xsl:use-attribute-sets="common.link">
      <fo:page-number-citation ref-id="{$value}"/>

      <xsl:variable name="start-range-value" as="attribute(value)?"
        select="ancestor-or-self::opentopic-index:index.entry[@start-range]/@value"/>

      <xsl:apply-templates mode="make-page-number-citation"
        select="key('refid-by-end-range-value', $start-range-value)"/>
    </fo:basic-link>
  </xsl:template>

  <xsl:template match="opentopic-index:refID" mode="make-page-number-citation">
    <xsl:text>-</xsl:text>
    <fo:page-number-citation
      ref-id="{opentopic-func:get-unique-refid-value(.)}"/>
  </xsl:template>

</xsl:stylesheet>
