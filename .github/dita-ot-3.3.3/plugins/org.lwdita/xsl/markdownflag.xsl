<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                version="2.0">

  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style">
    <!-- Add the pre-calculated CSS style for this element -->
    <xsl:attribute name="style"><xsl:value-of select="."/></xsl:attribute>
  </xsl:template>

  <!-- By default, process flags where encountered: at the start and end of the element content. -->
  <xsl:template match="*" mode="processFlagsInline">yes</xsl:template>
  <!-- For lists, process out-of-line in order to keep XHTML valid. -->
  <xsl:template match="*[contains(@class,' topic/ol ') or
                         contains(@class,' topic/ul ') or
                         contains(@class,' topic/sl ')]" mode="processFlagsInline">no</xsl:template>
  <xsl:template match="*[contains(@class,' topic/dl ') or
                         contains(@class,' topic/dlentry ') or
                         contains(@class,' topic/dlhead ')]" mode="processFlagsInline">no</xsl:template>
  <!-- Table flags have to be moved around to maintain XHTML validity -->
  <xsl:template match="*[contains(@class,' topic/table ') or
                         contains(@class,' topic/tgroup ') or
                         contains(@class,' topic/thead ') or
                         contains(@class,' topic/tbody ') or
                         contains(@class,' topic/row ') or
                         contains(@class,' topic/simpletable ') or
                         contains(@class,' topic/sthead ') or
                         contains(@class,' topic/strow ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For notes, process out-of-line to keep start flag ahead of generated heading -->
  <xsl:template match="*[contains(@class,' topic/note ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For fig, process out-of-line to keep start flag ahead of generated heading -->
  <xsl:template match="*[contains(@class,' topic/fig ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For pre, process out-of-line to keep start flag ahead of block, otherwise it throws off spacing -->
  <xsl:template match="*[contains(@class,' topic/pre ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For root topic, process out-of-line to get flags around headers/footers -->
  <xsl:template match="/*[contains(@class,' topic/topic ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For body, process out-of-line to get ahead of shortdesc/abstract, after links -->
  <xsl:template match="*[contains(@class,' topic/body ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For section or example, process out-of-line to get ahead flags ahead of the title -->
  <xsl:template match="*[contains(@class,' topic/section ') or 
                         contains(@class,' topic/example ')]" mode="processFlagsInline">no</xsl:template>
  <!-- For lq, process out-of-line to get end flags after citation info -->
  <xsl:template match="*[contains(@class,' topic/lq ')]" mode="processFlagsInline">no</xsl:template>
  <!-- Image should not hit this in fallthrough, but is explicitly processed before/after <img> -->
  <xsl:template match="*[contains(@class,' topic/image ')]" mode="processFlagsInline">no</xsl:template>
  <!-- If a tm symbol is generated, flag should go after -->
  <xsl:template match="*[contains(@class,' topic/tm ')]" mode="processFlagsInline">no</xsl:template>

  <!-- Link processing often works as fallthrough, but often not; do make link processing easier,
       handle all instances out-of-line. -->
  <xsl:template match="*[contains(@class,' topic/link ') or
                         contains(@class,' topic/linklist ')]" mode="processFlagsInline">no</xsl:template>

  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-startprop ')]">
    <xsl:variable name="processnow">
      <xsl:apply-templates select="parent::*" mode="processFlagsInline"/>
    </xsl:variable>
    <xsl:if test="$processnow='yes'">
      <xsl:apply-templates select="prop/startflag" mode="ditaval-outputflag"/>
      <xsl:apply-templates select="revprop/startflag" mode="ditaval-outputflag"/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line">
    <xsl:apply-templates select="prop/startflag" mode="ditaval-outputflag"/>
    <xsl:apply-templates select="revprop/startflag" mode="ditaval-outputflag"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-endprop ')]">
    <xsl:variable name="processnow">
      <xsl:apply-templates select="parent::*" mode="processFlagsInline"/>
    </xsl:variable>
    <xsl:if test="$processnow='yes'">
      <xsl:apply-templates select="revprop/endflag" mode="ditaval-outputflag"/>
      <xsl:apply-templates select="prop/endflag" mode="ditaval-outputflag"/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line">
    <xsl:apply-templates select="revprop/endflag" mode="ditaval-outputflag"/>
    <xsl:apply-templates select="prop/endflag" mode="ditaval-outputflag"/>
  </xsl:template>

  <xsl:template match="startflag|endflag" mode="ditaval-outputflag">
    <xsl:choose>
      <xsl:when test="@imageref">
        <img src="{@imageref}">
          <xsl:apply-templates select="alt-text" mode="ditaval-outputflag"/>
        </img>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="alt-text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="alt-text" mode="ditaval-outputflag">
    <xsl:attribute name="alt">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>