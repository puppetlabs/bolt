<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2014 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                version="2.0"
                exclude-result-prefixes="xs dita-ot ditamsg">

  <xsl:import href="plugin:org.dita.html5:xsl/dita2html5Impl.xsl"/>
  
  <dita:extension id="dita.xsl.html5.cover" 
    behavior="org.dita.dost.platform.ImportXSLAction" 
    xmlns:dita="http://dita-ot.sourceforge.net"/>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="toc">
    <xsl:param name="pathFromMaplist"/>
    <xsl:if test="descendant::*[contains(@class, ' map/topicref ')]
      [not(@toc = 'no')]
      [not(@processing-role = 'resource-only')]">
      <nav>
        <ul>
          <xsl:call-template name="commonattributes"/>
          <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
            <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
          </xsl:apply-templates>
        </ul>
      </nav>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/topicref ')]
    [not(@toc = 'no')]
    [not(@processing-role = 'resource-only')]"
    mode="toc">
    <xsl:param name="pathFromMaplist"/>
    <xsl:variable name="title">
      <xsl:apply-templates select="." mode="get-navtitle"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="normalize-space($title)">
        <li>
          <xsl:call-template name="commonattributes"/>
          <xsl:choose>
            <!-- If there is a reference to a DITA or HTML file, and it is not external: -->
            <xsl:when test="normalize-space(@href)">
              <a>
                <xsl:attribute name="href">
                  <xsl:choose>
                    <xsl:when test="@copy-to and not(contains(@chunk, 'to-content')) and 
                      (not(@format) or @format = 'dita' or @format = 'ditamap') ">
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:call-template name="replace-extension">
                        <xsl:with-param name="filename" select="@copy-to"/>
                        <xsl:with-param name="extension" select="$OUTEXT"/>
                      </xsl:call-template>
                      <xsl:if test="not(contains(@copy-to, '#')) and contains(@href, '#')">
                        <xsl:value-of select="concat('#', substring-after(@href, '#'))"/>
                      </xsl:if>
                    </xsl:when>
                    <xsl:when test="not(@scope = 'external') and (not(@format) or @format = 'dita' or @format = 'ditamap')">
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:call-template name="replace-extension">
                        <xsl:with-param name="filename" select="@href"/>
                        <xsl:with-param name="extension" select="$OUTEXT"/>
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise><!-- If non-DITA, keep the href as-is -->
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:value-of select="@href"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:attribute>
                <xsl:if test="@scope = 'external' or not(not(@format) or @format = 'dita' or @format = 'ditamap')">
                  <xsl:attribute name="target">_blank</xsl:attribute>
                </xsl:if>
                <xsl:value-of select="$title"/>
              </a>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$title"/>
            </xsl:otherwise>
          </xsl:choose>
          <!-- If there are any children that should be in the TOC, process them -->
          <xsl:if test="descendant::*[contains(@class, ' map/topicref ')]
            [not(@toc = 'no')]
            [not(@processing-role = 'resource-only')]">
            <ul>
              <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
                <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
              </xsl:apply-templates>
            </ul>
          </xsl:if>
        </li>
      </xsl:when>
      <xsl:otherwise><!-- if it is an empty topicref -->
        <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
          <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- If toc=no, but a child has toc=yes, that child should bubble up to the top -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]
    [@toc = 'no']
    [not(@processing-role = 'resource-only')]"
    mode="toc">
    <xsl:param name="pathFromMaplist"/>
    <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
      <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*" mode="toc" priority="-1"/>
  
  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:apply-templates select="." mode="root_element"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="chapterBody">
    <body>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
      <xsl:if test="@outputclass">
        <xsl:attribute name="class" select="@outputclass"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="addAttributesToBody"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:call-template name="generateBreadcrumbs"/>
      <xsl:call-template name="gen-user-header"/>
      <xsl:call-template name="processHDR"/>
      <xsl:if test="$INDEXSHOW = 'yes'">
        <xsl:apply-templates select="/*/*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/keywords ')]/*[contains(@class, ' topic/indexterm ')]"/>
      </xsl:if>
      <xsl:call-template name="gen-user-sidetoc"/>
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/title ')]">
          <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="@title"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:variable name="map" as="element()*">
        <xsl:apply-templates select="." mode="normalize-map"/>
      </xsl:variable>
      <xsl:apply-templates select="$map" mode="toc"/>
      <xsl:call-template name="gen-endnotes"/>
      <xsl:call-template name="gen-user-footer"/>
      <xsl:call-template name="processFTR"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </body>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]/*[contains(@class, ' topic/title ')]">
    <h1 class="title topictitle1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:apply-templates/>
    </h1>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]/@title">
    <h1 class="title topictitle1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:value-of select="."/>
    </h1>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]" priority="10">
    <h1 class="title topictitle1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:apply-templates select="*[contains(@class, ' bookmap/mainbooktitle ')]/node()"/>
    </h1>
  </xsl:template>
  
  <xsl:template name="generateChapterTitle">
    <title>
      <xsl:choose>
        <xsl:when test="/*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]/*[contains(@class, ' bookmap/mainbooktitle ')]">
          <xsl:call-template name="gen-user-panel-title-pfx"/>
          <xsl:value-of select="/*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]/*[contains(@class, ' bookmap/mainbooktitle ')]"/>
        </xsl:when>
        <xsl:when test="/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')]">
          <xsl:call-template name="gen-user-panel-title-pfx"/>
          <xsl:value-of select="/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')]"/>
        </xsl:when>
        <xsl:when test="/*[contains(@class,' map/map ')]/@title">
          <xsl:call-template name="gen-user-panel-title-pfx"/>
          <xsl:value-of select="/*[contains(@class,' map/map ')]/@title"/>
        </xsl:when>
      </xsl:choose>
    </title>
  </xsl:template>

</xsl:stylesheet>
