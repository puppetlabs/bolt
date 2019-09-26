<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project. 
See the accompanying license.txt file for applicable licenses.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0"
                exclude-result-prefixes="xs dita-ot">

  <xsl:template match="*[contains(@class, ' hazard-d/hazardstatement ')]">
    <xsl:variable name="type" select="(@type, 'caution')[1]" as="xs:string"/>
    <xsl:variable name="number-cells" as="xs:integer" select="2"/>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
    <fo:table xsl:use-attribute-sets="hazardstatement">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="globalAtts"/>
      <xsl:call-template name="displayAtts">
        <xsl:with-param name="element" select="."/>
      </xsl:call-template>
      <fo:table-column xsl:use-attribute-sets="hazardstatement.image.column"/>
      <fo:table-column xsl:use-attribute-sets="hazardstatement.content.column"/>
      <fo:table-body>
        <fo:table-row keep-with-next="always">
          <fo:table-cell xsl:use-attribute-sets="hazardstatement.title">
            <xsl:variable name="atts" as="element()">
              <xsl:choose>
                <xsl:when test="$type = 'danger'">
                  <w xsl:use-attribute-sets="hazardstatement.title.danger"/>
                </xsl:when>
                <xsl:when test="$type = 'warning'">
                  <w xsl:use-attribute-sets="hazardstatement.title.warning"/>
                </xsl:when>
                <xsl:when test="$type = 'caution'">
                  <w xsl:use-attribute-sets="hazardstatement.title.caution"/>
                </xsl:when>
                <xsl:otherwise>
                  <w xsl:use-attribute-sets="hazardstatement.title.notice"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:sequence select="$atts/@*"/>
            <fo:block>
              <xsl:if test="$type = ('danger', 'warning', 'caution')">
                <xsl:variable name="image" as="xs:string">
                  <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'hazard.image.default'"/>
                  </xsl:call-template>
                </xsl:variable>
                <fo:external-graphic src="url('{concat($artworkPrefix, $image)}')"
                                     content-height="1em" padding-right="3pt"
                                     vertical-align="middle"
                                     baseline-shift="baseline"/>
              </xsl:if>
              <fo:inline>
                <xsl:choose>
                  <xsl:when test="$type='other'"><xsl:value-of select="@othertype"/></xsl:when>
                  <xsl:otherwise>
                    <xsl:call-template name="getVariable">
                      <xsl:with-param name="id" select="dita-ot:capitalize($type)"/>
                    </xsl:call-template>
                  </xsl:otherwise>
                </xsl:choose>
              </fo:inline>
            </fo:block>
          </fo:table-cell>
        </fo:table-row>
        <fo:table-row>
          <fo:table-cell xsl:use-attribute-sets="hazardstatement.image">
              <xsl:choose>
              <xsl:when test="exists(*[contains(@class, ' hazard-d/hazardsymbol ')])">
                <xsl:apply-templates select="*[contains(@class, ' hazard-d/hazardsymbol ')]"/>
              </xsl:when>
              <xsl:otherwise>
                <fo:block>
                  <xsl:variable name="image" as="xs:string">
                    <xsl:call-template name="getVariable">
                      <xsl:with-param name="id" select="'hazard.image.default'"/>
                    </xsl:call-template>
                  </xsl:variable>
                  <fo:external-graphic src="url('{concat($artworkPrefix, $image)}')"
                    xsl:use-attribute-sets="hazardsymbol"/>
                </fo:block>
              </xsl:otherwise>
            </xsl:choose>
          </fo:table-cell>
          <fo:table-cell  xsl:use-attribute-sets="hazardstatement.content">
            <xsl:apply-templates select="*[contains(@class, ' hazard-d/messagepanel ')]/*"/>
          </fo:table-cell>
        </fo:table-row>
      </fo:table-body>
    </fo:table>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
  </xsl:template>
    
  <xsl:template match="*[contains(@class, ' hazard-d/messagepanel ')]">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' hazard-d/typeofhazard ')]">
    <fo:block xsl:use-attribute-sets="p">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:block>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' hazard-d/consequence ')]">
    <fo:block xsl:use-attribute-sets="p">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:block>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' hazard-d/howtoavoid ')]">
    <fo:block xsl:use-attribute-sets="p">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:block>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' hazard-d/hazardsymbol ')]">
    <fo:block>
      <xsl:next-match/>
    </fo:block>
  </xsl:template>
    
</xsl:stylesheet>