<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
     xmlns:xs="http://www.w3.org/2001/XMLSchema"
     exclude-result-prefixes="ditamsg xs">

<!-- == User Technologies UNIQUE SUBSTRUCTURES == -->

<!-- imagemap -->
<xsl:template match="*[contains(@class,' ut-d/imagemap ')]" name="topic.ut-d.imagemap">
  <div>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>

    <!-- the image -->
    <img usemap="#{generate-id()}">
      <!-- Border attribute defaults to 0 -->
      <xsl:apply-templates select="." mode="imagemap-border-attribute"/>
      <!-- Process the 'normal' image attributes, using this special mode -->
      <xsl:apply-templates select="*[contains(@class,' topic/image ')]" mode="imagemap-image"/>
    </img>
    <xsl:value-of select="$newline"/>

    <map name="{generate-id(.)}" id="{generate-id(.)}">

      <xsl:for-each select="*[contains(@class,' ut-d/area ')]">
        <xsl:value-of select="$newline"/>
        <area>

          <!-- if no xref/@href - error -->
          <xsl:choose>
            <xsl:when test="*[contains(@class,' topic/xref ')]/@href">
              <!-- special call to have the XREF/@HREF processor do the work -->
              <xsl:apply-templates select="*[contains(@class, ' topic/xref ')]" mode="imagemap-xref"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="." mode="ditamsg:area-element-without-href-target"/>
            </xsl:otherwise>
          </xsl:choose>

          <!-- create ALT text from XREF content-->
          <!-- if no XREF content, use @HREF, & put out a warning -->
          <xsl:choose>
            <xsl:when test="*[contains(@class, ' topic/xref ')]">
              <xsl:variable name="alttext"><xsl:apply-templates select="*[contains(@class, ' topic/xref ')]/node()[not(contains(@class, ' topic/desc '))]" mode="text-only"/></xsl:variable>
              <xsl:attribute name="alt"><xsl:value-of select="normalize-space($alttext)"/></xsl:attribute>
              <xsl:attribute name="title"><xsl:value-of select="normalize-space($alttext)"/></xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="." mode="ditamsg:area-element-without-linktext"/>
            </xsl:otherwise>
          </xsl:choose>

          <!-- if not valid shape (blank, rect, circle, poly); Warning, pass thru the value -->
          <xsl:variable name="shapeval"><xsl:value-of select="*[contains(@class,' ut-d/shape ')]"/></xsl:variable>
          <xsl:attribute name="shape">
            <xsl:value-of select="$shapeval"/>
          </xsl:attribute>
          <xsl:variable name="shapetest" select="concat('-',$shapeval,'-')" as="xs:string"/>
          <xsl:choose>
            <xsl:when test="contains('--rect-circle-poly-default-',$shapetest)"/>
            <xsl:otherwise>
              <xsl:apply-templates select="." mode="ditamsg:area-element-unknown-shape">
                <xsl:with-param name="shapeval" select="$shapeval"/>
              </xsl:apply-templates>
            </xsl:otherwise>
          </xsl:choose>

          <!-- if no coords & shape<>'default'; Warning, pass thru the value -->
          <xsl:variable name="coordval"><xsl:value-of select="*[contains(@class,' ut-d/coords ')]"/></xsl:variable>
          <xsl:choose>
            <xsl:when test="string-length($coordval)>0 and not($shapeval='default')">
              <xsl:attribute name="coords">
                <xsl:value-of select="$coordval"/>
              </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="." mode="ditamsg:area-element-missing-coords"/>
            </xsl:otherwise>
          </xsl:choose>

        </area>
      </xsl:for-each>

      <xsl:value-of select="$newline"/>
    </map>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </div>
</xsl:template>

<!-- Set the border attribute on an imagemap; default is to always use border="0" -->
<xsl:template match="*[contains(@class,' ut-d/imagemap ')]" mode="imagemap-border-attribute">
  <xsl:attribute name="border">0</xsl:attribute>
</xsl:template>

<!-- In the context of IMAGE - call these attribute processors -->
<xsl:template match="*[contains(@class, ' topic/image ')]" mode="imagemap-image">
  <xsl:call-template name="commonattributes"/>
  <xsl:call-template name="setid"/>
  <xsl:apply-templates select="@href|@height|@width"/>
  <xsl:choose>
    <xsl:when test="*[contains(@class, ' topic/longdescref ')]">
      <xsl:apply-templates select="*[contains(@class, ' topic/longdescref ')]"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="@longdescref"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
    <xsl:when test="*[contains(@class,' topic/alt ')]">
      <xsl:attribute name="alt"><xsl:apply-templates select="*[contains(@class,' topic/alt ')]" mode="text-only"/></xsl:attribute>
    </xsl:when>
    <xsl:when test="@alt">
      <xsl:attribute name="alt"><xsl:value-of select="@alt"/></xsl:attribute>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<!-- In the context of XREF - call it's HREF processor -->
<xsl:template match="*[contains(@class, ' topic/xref ')]" mode="imagemap-xref">
 <xsl:attribute name="href"><xsl:call-template name="href"/></xsl:attribute>
 <xsl:if test="@scope='external' or @type='external' or ((@format='PDF' or @format='pdf') and not(@scope='local'))">
  <xsl:attribute name="target">_blank</xsl:attribute>
 </xsl:if>
</xsl:template>

<xsl:template match="*" mode="ditamsg:area-element-without-href-target">
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX044E'"/>
  </xsl:call-template>
</xsl:template>
<xsl:template match="*" mode="ditamsg:area-element-without-linktext">
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX045W'"/>
  </xsl:call-template>
</xsl:template>
<xsl:template match="*" mode="ditamsg:area-element-unknown-shape">
  <xsl:param name="shapeval" select="*[contains(@class,' ut-d/shape ')]/text()"/>
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX046W'"/>
    <xsl:with-param name="msgparams">%1=<xsl:value-of select="$shapeval"/></xsl:with-param>
  </xsl:call-template>
</xsl:template>
<xsl:template match="*" mode="ditamsg:area-element-missing-coords">
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX047W'"/>
  </xsl:call-template>
</xsl:template>

</xsl:stylesheet>
