<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  version="2.0"
  exclude-result-prefixes="xs dita-ot">

    <xsl:template match="*[contains(@class, ' topic/dt ')]">
        <fo:block xsl:use-attribute-sets="dlentry.dt__content">
            <xsl:call-template name="commonattributes"/>
            <xsl:if test="not(preceding-sibling::*[contains(@class,' topic/dt ')])">
              <xsl:apply-templates select="../@id" mode="dlentry-id-for-fop"/>
              <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
            </xsl:if>
            <xsl:apply-templates select="." mode="inlineTextOptionalKeyref"/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/dlentry ')]/@id">
      <!-- FOP does not support @id on table rows; drop from the row and add to an <fo:inline> in the first term. -->
    </xsl:template>
    <xsl:template match="@id" mode="dlentry-id-for-fop">
        <fo:inline id="{.}"/>
    </xsl:template>

  <xsl:template match="*[contains(@class,' topic/entry ')]">
    <xsl:choose>
      <xsl:when test="dita-ot:get-entry-end-position(.) gt number(ancestor::*[contains(@class,' topic/tgroup ')][1]/@cols)">
        <!-- FOP crashes if an entry extends beyond the table width -->
        <xsl:call-template name="output-message">
          <xsl:with-param name="id" select="'PDFX012E'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:next-match/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- By default in FOP, rotated text in a table entry does not change the cell size, so rotated text will overwrite other cells.
       To enable rotation, explicitly set the height and width as follows:
       1) Uncomment the fo:block-container
       2) Adjust the height and width values to either
       2a) An appropriate default that is acceptable for all of your rotated cells, or
       2b) A specific or calculated value based on the cell content --> 
  <xsl:template match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="rotateTableEntryContent">
    <!--<fo:block-container reference-orientation="90" width="150px" height="80px">-->
      <fo:block xsl:use-attribute-sets="thead.row.entry__content">
        <xsl:call-template name="processEntryContent"/>
      </fo:block>
    <!--</fo:block-container>-->
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/tbody ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="rotateTableEntryContent">
    <!--<fo:block-container reference-orientation="90" width="150px" height="80px">-->
      <fo:block xsl:use-attribute-sets="tbody.row.entry__content">
        <xsl:call-template name="processEntryContent"/>
      </fo:block>
    <!--</fo:block-container>-->
  </xsl:template>

</xsl:stylesheet>
