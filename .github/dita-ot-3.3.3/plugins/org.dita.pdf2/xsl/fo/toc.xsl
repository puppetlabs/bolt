<?xml version='1.0'?>

<!--
Copyright © 2004-2006 by Idiom Technologies, Inc. All rights reserved.
IDIOM is a registered trademark of Idiom Technologies, Inc. and WORLDSERVER
and WORLDSTART are trademarks of Idiom Technologies, Inc. All other
trademarks are the property of their respective owners.

IDIOM TECHNOLOGIES, INC. IS DELIVERING THE SOFTWARE "AS IS," WITH
ABSOLUTELY NO WARRANTIES WHATSOEVER, WHETHER EXPRESS OR IMPLIED,  AND IDIOM
TECHNOLOGIES, INC. DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE AND WARRANTY OF NON-INFRINGEMENT. IDIOM TECHNOLOGIES, INC. SHALL NOT
BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, COVER, PUNITIVE, EXEMPLARY,
RELIANCE, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF
ANTICIPATED PROFIT), ARISING FROM ANY CAUSE UNDER OR RELATED TO  OR ARISING
OUT OF THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF IDIOM
TECHNOLOGIES, INC. HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

Idiom Technologies, Inc. and its licensors shall not be liable for any
damages suffered by any person as a result of using and/or modifying the
Software or its derivatives. In no event shall Idiom Technologies, Inc.'s
liability for any damages hereunder exceed the amounts received by Idiom
Technologies, Inc. as a result of this transaction.

These terms and conditions supersede the terms and conditions in any
licensing agreement to the extent that such terms and conditions conflict
with those set forth herein.

This file is part of the DITA Open Toolkit project.
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    xmlns:opentopic="http://www.idiominc.com/opentopic"
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
    exclude-result-prefixes="xs dita-ot opentopic opentopic-func ot-placeholder opentopic-index"
    version="2.0">
  
    <xsl:variable name="map" select="//opentopic:map"/>

    <xsl:template name="createTocHeader">
        <fo:block xsl:use-attribute-sets="__toc__header" id="{$id.toc}">
            <xsl:apply-templates select="." mode="customTopicAnchor"/>
            <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="'Table of Contents'"/>
            </xsl:call-template>
        </fo:block>
    </xsl:template>
    
    <xsl:template match="/" mode="toc">
        <xsl:apply-templates mode="toc">
            <xsl:with-param name="include" select="'true'"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="toc">
        <xsl:param name="include"/>
        <xsl:variable name="topicLevel" as="xs:integer">
          <xsl:apply-templates select="." mode="get-topic-level"/>
        </xsl:variable>
        <xsl:if test="$topicLevel &lt; $tocMaximumLevel">
            <xsl:variable name="mapTopicref" select="key('map-id', @id)[1]" as="element()?"/>
            <xsl:choose>
              <!-- In a future version, suppressing Notices in the TOC should not be hard-coded. -->
              <xsl:when test="$retain-bookmap-order and $mapTopicref/self::*[contains(@class, ' bookmap/notices ')]"/>
              <xsl:when test="$mapTopicref[@toc = 'yes' or not(@toc)] or
                              (not($mapTopicref) and $include = 'true')">
                    <fo:block xsl:use-attribute-sets="__toc__indent">
                        <xsl:variable name="tocItemContent">
                          <fo:basic-link xsl:use-attribute-sets="__toc__link">
                            <xsl:attribute name="internal-destination">
                              <xsl:call-template name="generate-toc-id"/>
                            </xsl:attribute>
                            <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]/revprop[@changebar]" mode="changebar">
                                <xsl:with-param name="changebar-id" select="concat(dita-ot:generate-changebar-id(.),'-toc')"/>
                            </xsl:apply-templates>
                            <xsl:apply-templates select="$mapTopicref" mode="tocPrefix"/>
                            <fo:inline xsl:use-attribute-sets="__toc__title">
                                <xsl:variable name="pulledNavigationTitle" as="item()*">
                                    <xsl:call-template name="getNavTitle" />
                                </xsl:variable>
                                <xsl:apply-templates select="$pulledNavigationTitle" mode="dropCopiedIds"/>
                            </fo:inline>
                            <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]/revprop[@changebar]" mode="changebar">
                                <xsl:with-param name="changebar-id" select="concat(dita-ot:generate-changebar-id(.),'-toc')"/>
                            </xsl:apply-templates>
                            <fo:inline xsl:use-attribute-sets="__toc__page-number">
                                <fo:leader xsl:use-attribute-sets="__toc__leader"/>
                                <fo:page-number-citation>
                                  <xsl:attribute name="ref-id">
                                    <xsl:call-template name="generate-toc-id"/>
                                  </xsl:attribute>
                                </fo:page-number-citation>
                            </fo:inline>
                        </fo:basic-link>
                        </xsl:variable>
                        <xsl:choose>
                          <xsl:when test="not($mapTopicref)">
                            <xsl:apply-templates select="." mode="tocText">
                              <xsl:with-param name="tocItemContent" select="$tocItemContent"/>
                              <xsl:with-param name="currentNode" select="."/>
                            </xsl:apply-templates>
                          </xsl:when>
                          <xsl:otherwise>
                            <xsl:apply-templates select="$mapTopicref" mode="tocText">
                              <xsl:with-param name="tocItemContent" select="$tocItemContent"/>
                              <xsl:with-param name="currentNode" select="."/>
                            </xsl:apply-templates>
                          </xsl:otherwise>
                        </xsl:choose>
                    </fo:block>
                    <xsl:apply-templates mode="toc">
                        <xsl:with-param name="include" select="'true'"/>
                    </xsl:apply-templates>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates mode="toc">
                        <xsl:with-param name="include" select="'true'"/>
                </xsl:apply-templates>
              </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' bookmap/chapter ')] |
                         *[contains(@class, ' bookmap/bookmap ')]/opentopic:map/*[contains(@class, ' map/topicref ')]" mode="tocPrefix" priority="-1">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table of Contents Chapter'"/>
            <xsl:with-param name="params">
                <number>
                    <xsl:apply-templates select="." mode="topicTitleNumber"/>
                </number>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/appendices ')]" mode="tocPrefix"/>
    
    <xsl:template match="*[contains(@class, ' bookmap/appendix ')]" mode="tocPrefix">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table of Contents Appendix'"/>
            <xsl:with-param name="params">
                <number>
                    <xsl:apply-templates select="." mode="topicTitleNumber"/>
                </number>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/part ')]" mode="tocPrefix">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table of Contents Part'"/>
            <xsl:with-param name="params">
                <number>
                    <xsl:apply-templates select="." mode="topicTitleNumber"/>
                </number>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/preface ')]" mode="tocPrefix">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table of Contents Preface'"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/notices ')]" mode="tocPrefix">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table of Contents Notices'"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="node()" mode="tocPrefix" priority="-10"/>
  
    <xsl:template match="*[contains(@class, ' bookmap/chapter ')] |
                         opentopic:map/*[contains(@class, ' map/topicref ')]" mode="tocText" priority="-1">
        <xsl:param name="tocItemContent"/>
        <xsl:param name="currentNode"/>
        <xsl:for-each select="$currentNode">
          <fo:block xsl:use-attribute-sets="__toc__chapter__content">
              <xsl:copy-of select="$tocItemContent"/>
          </fo:block>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/appendix ')]" mode="tocText">
        <xsl:param name="tocItemContent"/>
        <xsl:param name="currentNode"/>
        <xsl:for-each select="$currentNode">
          <fo:block xsl:use-attribute-sets="__toc__appendix__content">
              <xsl:copy-of select="$tocItemContent"/>
          </fo:block>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/part ')]" mode="tocText">
        <xsl:param name="tocItemContent"/>
        <xsl:param name="currentNode"/>
        <xsl:for-each select="$currentNode">
          <fo:block xsl:use-attribute-sets="__toc__part__content">
              <xsl:copy-of select="$tocItemContent"/>
          </fo:block>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/preface ')]" mode="tocText">
        <xsl:param name="tocItemContent"/>
        <xsl:param name="currentNode"/>
        <xsl:for-each select="$currentNode">
          <fo:block xsl:use-attribute-sets="__toc__preface__content">
              <xsl:copy-of select="$tocItemContent"/>
          </fo:block>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*[contains(@class, ' bookmap/notices ')]" mode="tocText">
        <xsl:param name="tocItemContent"/>
        <xsl:param name="currentNode"/>
        <xsl:for-each select="$currentNode">
          <fo:block xsl:use-attribute-sets="__toc__notices__content">
              <xsl:copy-of select="$tocItemContent"/>
          </fo:block>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="node()" mode="tocText" priority="-10">
        <xsl:param name="tocItemContent"/>
        <xsl:param name="currentNode"/>
        <xsl:for-each select="$currentNode">
          <fo:block xsl:use-attribute-sets="__toc__topic__content">
              <xsl:copy-of select="$tocItemContent"/>
          </fo:block>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="node()" mode="toc">
        <xsl:param name="include"/>
        <xsl:apply-templates mode="toc">
            <xsl:with-param name="include" select="$include"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template name="createToc">
      <xsl:if test="$generate-toc">
        <xsl:variable name="toc">
            <xsl:choose>
                <xsl:when test="$map//*[contains(@class,' bookmap/toc ')][@href]"/>
                <xsl:when test="$map//*[contains(@class,' bookmap/toc ')]">
                    <xsl:apply-templates select="/" mode="toc"/>
                </xsl:when>
                <xsl:when test="/*[contains(@class,' map/map ')][not(contains(@class,' bookmap/bookmap '))]">
                    <xsl:apply-templates select="/" mode="toc"/>
                    <xsl:call-template name="toc.index"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="count($toc/*) > 0">
            <fo:page-sequence master-reference="toc-sequence" xsl:use-attribute-sets="page-sequence.toc">
                <xsl:call-template name="insertTocStaticContents"/>
                <fo:flow flow-name="xsl-region-body">
                    <xsl:call-template name="createTocHeader"/>
                    <fo:block>
                        <fo:marker marker-class-name="current-header">
                          <xsl:call-template name="getVariable">
                            <xsl:with-param name="id" select="'Table of Contents'"/>
                          </xsl:call-template>
                        </fo:marker>
                        <xsl:apply-templates select="." mode="customTopicMarker"/>
                        <xsl:copy-of select="$toc"/>
                    </fo:block>
                </fo:flow>
            </fo:page-sequence>
        </xsl:if>
      </xsl:if>
    </xsl:template>

    <xsl:template name="processTocList">
        <fo:page-sequence master-reference="toc-sequence" xsl:use-attribute-sets="page-sequence.toc">
            <xsl:call-template name="insertTocStaticContents"/>
            <fo:flow flow-name="xsl-region-body">
                <xsl:call-template name="createTocHeader"/>
                <fo:block>
                    <xsl:apply-templates/>
                </fo:block>
            </fo:flow>
        </fo:page-sequence>
    </xsl:template>

  <xsl:template match="ot-placeholder:toc[$retain-bookmap-order]">
    <xsl:call-template name="createToc"/>
  </xsl:template>
    
  <xsl:template match="ot-placeholder:indexlist" mode="toc" name="toc.index">
    <xsl:if test="(//opentopic-index:index.groups//opentopic-index:index.entry) and (exists($index-entries//opentopic-index:index.entry))">
      <fo:block xsl:use-attribute-sets="__toc__indent__booklist">
        <fo:block xsl:use-attribute-sets="__toc__topic__content__booklist">
          <fo:basic-link internal-destination="{$id.index}" xsl:use-attribute-sets="__toc__link">
            <fo:inline xsl:use-attribute-sets="__toc__title">
              <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="'Index'"/>
              </xsl:call-template>
            </fo:inline>
            <fo:inline xsl:use-attribute-sets="__toc__page-number">
              <fo:leader xsl:use-attribute-sets="__toc__leader"/>
              <fo:page-number-citation ref-id="{$id.index}"/>
            </fo:inline>
          </fo:basic-link>
        </fo:block>
      </fo:block>
    </xsl:if>
  </xsl:template>
    
    <xsl:template match="ot-placeholder:glossarylist" mode="toc">
        <fo:block xsl:use-attribute-sets="__toc__indent__glossary">
            <fo:block xsl:use-attribute-sets="__toc__topic__content__glossary">
                <fo:basic-link internal-destination="{$id.glossary}" xsl:use-attribute-sets="__toc__link">
                    <fo:inline xsl:use-attribute-sets="__toc__title">
                        <xsl:call-template name="getVariable">
                            <xsl:with-param name="id" select="'Glossary'"/>
                        </xsl:call-template>
                    </fo:inline>
                    <fo:inline xsl:use-attribute-sets="__toc__page-number">
                        <fo:leader xsl:use-attribute-sets="__toc__leader"/>
                        <fo:page-number-citation ref-id="{$id.glossary}"/>
                    </fo:inline>
                </fo:basic-link>
            </fo:block>
        </fo:block>
    </xsl:template>
    
    <xsl:template match="ot-placeholder:tablelist" mode="toc">
        <xsl:if test="//*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ' )]">
            <fo:block xsl:use-attribute-sets="__toc__indent__lot">
                <fo:block xsl:use-attribute-sets="__toc__topic__content__lot">
                    <fo:basic-link internal-destination="{$id.lot}" xsl:use-attribute-sets="__toc__link">
                        <fo:inline xsl:use-attribute-sets="__toc__title">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'List of Tables'"/>
                            </xsl:call-template>
                        </fo:inline>
                        <fo:inline xsl:use-attribute-sets="__toc__page-number">
                            <fo:leader xsl:use-attribute-sets="__toc__leader"/>
                            <fo:page-number-citation ref-id="{$id.lot}"/>
                        </fo:inline>
                    </fo:basic-link>
                </fo:block>
            </fo:block>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="ot-placeholder:figurelist" mode="toc">
        <xsl:if test="//*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/title ' )]">
            <fo:block xsl:use-attribute-sets="__toc__indent__lof">
                <fo:block xsl:use-attribute-sets="__toc__topic__content__lof">
                    <fo:basic-link internal-destination="{$id.lof}" xsl:use-attribute-sets="__toc__link">
                        <fo:inline xsl:use-attribute-sets="__toc__title">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'List of Figures'"/>
                            </xsl:call-template>
                        </fo:inline>
                        <fo:inline xsl:use-attribute-sets="__toc__page-number">
                            <fo:leader xsl:use-attribute-sets="__toc__leader"/>
                            <fo:page-number-citation ref-id="{$id.lof}"/>
                        </fo:inline>
                    </fo:basic-link>
                </fo:block>
            </fo:block>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' glossentry/glossentry ')]" mode="toc" priority="10"/>

</xsl:stylesheet>
