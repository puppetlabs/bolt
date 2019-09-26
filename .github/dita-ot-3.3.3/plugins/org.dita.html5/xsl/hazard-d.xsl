<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project. 
See the accompanying license.txt file for applicable licenses.
-->
<xsl:stylesheet version="2.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
     xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
     xmlns:xs="http://www.w3.org/2001/XMLSchema"
     exclude-result-prefixes="ditamsg dita-ot xs">
  
  <xsl:param name="inline-hazard-svg" as="element()" select="document('plugin:org.dita.html5:resources/ISO_7010_W001_html.svg')/*"/>  
  
  <xsl:template match="*[contains(@class,' hazard-d/messagepanel ')]" mode="get-element-ancestry"><xsl:value-of select="name()"/></xsl:template>
  <xsl:template match="*[contains(@class,' hazard-d/messagepanel ')]/*" mode="get-element-ancestry"><xsl:value-of select="name()"/></xsl:template>
  <xsl:template match="*[contains(@class,' hazard-d/hazardstatement ')]">
    <xsl:variable name="type" select="(@type, 'caution')[1]" as="xs:string"/>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
    <table role="presentation" border="1">
      <xsl:call-template name="commonattributes"/>
      <tr>
        <th colspan="2" class="hazardstatement--{$type}">
          <xsl:if test="$type = ('danger', 'warning', 'caution')">
            <xsl:for-each select="$inline-hazard-svg">
              <xsl:copy>
                <xsl:sequence select="@*"/>
                <xsl:attribute name="height" select="'1em'"/>
                <xsl:sequence select="*"/>
              </xsl:copy>
            </xsl:for-each>
            <xsl:text> </xsl:text>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="$type='other'"><xsl:value-of select="@othertype"></xsl:value-of></xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="dita-ot:capitalize($type)"/>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </th>
      </tr>
      <tr>
        <td>
          <xsl:apply-templates select="*[contains(@class,' hazard-d/hazardsymbol ')]"/>
          <xsl:if test="empty(*[contains(@class,' hazard-d/hazardsymbol ')])">
            <xsl:sequence select="$inline-hazard-svg"/>
          </xsl:if>
        </td>
        <td>
          <xsl:apply-templates select="*[contains(@class,' hazard-d/messagepanel ')]"/>
        </td>
      </tr>
    </table>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]"/>
  </xsl:template>
  <xsl:template match="*[contains(@class,' hazard-d/messagepanel ')]">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  <xsl:template match="*[contains(@class,' hazard-d/messagepanel ')]/*">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
</xsl:stylesheet>
