<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Eero Helenius

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:table="http://dita-ot.sourceforge.net/ns/201007/dita-ot/table"
                xmlns:simpletable="http://dita-ot.sourceforge.net/ns/201007/dita-ot/simpletable"
                version="2.0"
                exclude-result-prefixes="xs dita-ot table simpletable">

  <xsl:variable name="empty-property" as="element(property)">
    <property class="- topic/strow reference/property ">
      <proptype class="- topic/stentry reference/proptype "/>
      <propvalue class="- topic/stentry reference/propvalue "/>
      <propdesc class="- topic/stentry reference/propdesc "/>
    </property>
  </xsl:variable>
  
  <xsl:template match="*[contains(@class, ' reference/property ')]
    [empty(*[contains(@class,' reference/proptype ') or contains(@class,' reference/propvalue ') or contains(@class,' reference/propdesc ')])]" priority="10"/>

  <xsl:template match="*[contains(@class, ' reference/property ')]">
    <xsl:variable name="property" select="." as="element()"/>

    <tr>
      <xsl:apply-templates select="." mode="table:common"/>

      <xsl:for-each select="(' reference/proptype ', ' reference/propvalue ', ' reference/propdesc ')">
        <xsl:variable name="class" select="." as="xs:string"/>

        <xsl:choose>
          <xsl:when test="exists($property/*[contains(@class, $class)])">
            <xsl:apply-templates select="$property/*[contains(@class, $class)]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="$empty-property/*[contains(@class, $class)]">
              <xsl:with-param name="ctx" select="$property" as="element()" tunnel="yes"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </tr>
  </xsl:template>

  <xsl:template mode="generate-table-header" match="
    *[contains(@class,' reference/properties ')]
     [empty(*[contains(@class,' reference/prophead ')])]
  ">
    <prophead class="- topic/sthead reference/prophead ">
      <proptypehd class="- topic/stentry task/proptypehd ">
        <xsl:sequence select="dita-ot:get-variable(., 'Type')"/>
      </proptypehd>

      <propvaluehd class="- topic/stentry task/propvaluehd ">
        <xsl:sequence select="dita-ot:get-variable(., 'Value')"/>
      </propvaluehd>

      <propdeschd class="- topic/stentry task/propdeschd ">
        <xsl:sequence select="dita-ot:get-variable(., 'Description')"/>
      </propdeschd>
    </prophead>
  </xsl:template>

  <xsl:template mode="headers" match="
    *[contains(@class, ' reference/property ')]/*
  ">
    <xsl:param name="ctx" as="element()" tunnel="yes" select="."/>

    <xsl:variable name="table" as="element()" select="
      simpletable:get-current-table($ctx)
    "/>

    <xsl:variable name="name" as="xs:string" select="
      substring-after(local-name(), 'prop')
    "/>

    <xsl:variable name="header" as="element()?" select="
      $table/*/*[contains(@class, concat(' reference/prop', $name, 'hd '))]
    "/>

    <xsl:attribute name="headers" select="
      ($header/@id,
       generate-id($header),
       simpletable:generate-headers($table, $name))[normalize-space(.)][1]
    "/>
  </xsl:template>

</xsl:stylesheet>
