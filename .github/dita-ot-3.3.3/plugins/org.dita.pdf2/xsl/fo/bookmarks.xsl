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
                xmlns:opentopic="http://www.idiominc.com/opentopic"
                xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
                xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
                xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
                exclude-result-prefixes="xs opentopic-index opentopic opentopic-func ot-placeholder"
                version="2.0">

    <!-- Determines whether letter headings in an index generate bookmarks.
         0 = no bookmarks.
         Any other number = if total # of terms exceeds $bookmarks.index-group-size, generate headers.
         To always generate headers, set to 1. -->
    <xsl:param name="bookmarks.index-group-size" as="xs:integer">100</xsl:param>

    <xsl:variable name="map" select="//opentopic:map"/>

    <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="bookmark">
        <xsl:variable name="mapTopicref" select="key('map-id', @id)[1]" as="element()?"/>
        <xsl:variable name="topicTitle">
            <xsl:call-template name="getNavTitle"/>
        </xsl:variable>
        
        <xsl:choose>
          <xsl:when test="$mapTopicref[@toc = 'yes' or not(@toc)] or
                          not($mapTopicref)">
            <fo:bookmark>
                <xsl:attribute name="internal-destination">
                    <xsl:call-template name="generate-toc-id"/>
                </xsl:attribute>
                    <xsl:if test="$bookmarkStyle!='EXPANDED'">
                        <xsl:attribute name="starting-state">hide</xsl:attribute>
                    </xsl:if>
                <fo:bookmark-title>
                    <xsl:value-of select="normalize-space($topicTitle)"/>
                </fo:bookmark-title>
                <xsl:apply-templates mode="bookmark"/>
            </fo:bookmark>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates mode="bookmark"/>
          </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="bookmark">
        <xsl:apply-templates mode="bookmark"/>
    </xsl:template>

    <xsl:template match="text()" mode="bookmark"/>

    <xsl:template name="createBookmarks">
      <xsl:variable name="bookmarks" as="element()*">
        <xsl:choose>
          <xsl:when test="$retain-bookmap-order">
            <xsl:apply-templates select="/" mode="bookmark"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:for-each select="/*/*[contains(@class, ' topic/topic ')]">
              <xsl:variable name="topicType">
                <xsl:call-template name="determineTopicType"/>
              </xsl:variable>
              <xsl:if test="$topicType = 'topicNotices'">
                <xsl:apply-templates select="." mode="bookmark"/>
              </xsl:if>
            </xsl:for-each>
            <xsl:choose>
                <xsl:when test="$map//*[contains(@class,' bookmap/toc ')][@href]"/>
                <xsl:when test="$map//*[contains(@class,' bookmap/toc ')]
                              | /*[contains(@class,' map/map ')][not(contains(@class,' bookmap/bookmap '))]">
                    <fo:bookmark internal-destination="{$id.toc}">
                        <fo:bookmark-title>
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Table of Contents'"/>
                            </xsl:call-template>
                        </fo:bookmark-title>
                    </fo:bookmark>
                </xsl:when>
            </xsl:choose>
            <xsl:for-each select="/*/*[contains(@class, ' topic/topic ')] |
                                  /*/ot-placeholder:glossarylist |
                                  /*/ot-placeholder:tablelist |
                                  /*/ot-placeholder:figurelist">
              <xsl:variable name="topicType">
                <xsl:call-template name="determineTopicType"/>
              </xsl:variable>
              <xsl:if test="not($topicType = 'topicNotices')">
                <xsl:apply-templates select="." mode="bookmark"/>
              </xsl:if>
            </xsl:for-each>
            <xsl:apply-templates select="/*" mode="bookmark-index"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:if test="exists($bookmarks)">
        <fo:bookmark-tree>
          <xsl:copy-of select="$bookmarks"/>
        </fo:bookmark-tree>
      </xsl:if>
    </xsl:template>

    <xsl:template match="ot-placeholder:toc[$retain-bookmap-order]" mode="bookmark">
        <fo:bookmark internal-destination="{$id.toc}">
            <xsl:if test="$bookmarkStyle!='EXPANDED'">
                <xsl:attribute name="starting-state">hide</xsl:attribute>
            </xsl:if>
            <fo:bookmark-title>
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Table of Contents'"/>
                </xsl:call-template>
            </fo:bookmark-title>
        </fo:bookmark>
    </xsl:template>
    
    <xsl:template match="ot-placeholder:indexlist[$retain-bookmap-order]" mode="bookmark">
        <fo:bookmark internal-destination="{$id.index}">
            <xsl:if test="$bookmarkStyle!='EXPANDED'">
                <xsl:attribute name="starting-state">hide</xsl:attribute>
            </xsl:if>
            <fo:bookmark-title>
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Index'"/>
                </xsl:call-template>
            </fo:bookmark-title>
        </fo:bookmark>
    </xsl:template>
    
    <xsl:template match="ot-placeholder:glossarylist" mode="bookmark">
        <fo:bookmark internal-destination="{$id.glossary}">
            <xsl:if test="$bookmarkStyle!='EXPANDED'">
                <xsl:attribute name="starting-state">hide</xsl:attribute>
            </xsl:if>
            <fo:bookmark-title>
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Glossary'"/>
                </xsl:call-template>
            </fo:bookmark-title>
            
            <xsl:apply-templates mode="bookmark"/>
        </fo:bookmark>
    </xsl:template>
    
    <xsl:template match="ot-placeholder:tablelist" mode="bookmark">
        <xsl:if test="//*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ' )]">
            <fo:bookmark internal-destination="{$id.lot}">
                <xsl:if test="$bookmarkStyle!='EXPANDED'">
                    <xsl:attribute name="starting-state">hide</xsl:attribute>
                </xsl:if>
                <fo:bookmark-title>
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'List of Tables'"/>
                    </xsl:call-template>
                </fo:bookmark-title>
                
                <xsl:apply-templates mode="bookmark"/>
            </fo:bookmark>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="ot-placeholder:figurelist" mode="bookmark">
        <xsl:if test="//*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/title ' )]">
            <fo:bookmark internal-destination="{$id.lof}">
                <xsl:if test="$bookmarkStyle!='EXPANDED'">
                    <xsl:attribute name="starting-state">hide</xsl:attribute>
                </xsl:if>
                <fo:bookmark-title>
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'List of Figures'"/>
                    </xsl:call-template>
                </fo:bookmark-title>
                
                <xsl:apply-templates mode="bookmark"/>
            </fo:bookmark>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*" mode="bookmark-index">
      <xsl:if test="//opentopic-index:index.groups//opentopic-index:index.entry">
          <xsl:choose>
              <xsl:when test="$map//*[contains(@class,' bookmap/indexlist ')][@href]"/>
              <xsl:when test="$map//*[contains(@class,' bookmap/indexlist ')]
                            | /*[contains(@class,' map/map ')][not(contains(@class,' bookmap/bookmap '))]">
                  <fo:bookmark internal-destination="{$id.index}" starting-state="hide">
                      <fo:bookmark-title>
                          <xsl:call-template name="getVariable">
                              <xsl:with-param name="id" select="'Index'"/>
                          </xsl:call-template>
                      </fo:bookmark-title>
                      <xsl:if test="$bookmarks.index-group-size !=0 and 
                                    count(//opentopic-index:index.groups//opentopic-index:index.entry) &gt; $bookmarks.index-group-size">
                        <xsl:apply-templates select="//opentopic-index:index.groups" mode="bookmark-index"/>
                      </xsl:if>
                  </fo:bookmark>
              </xsl:when>
          </xsl:choose>
      </xsl:if>
    </xsl:template>

    <xsl:template match="opentopic-index:index.groups" mode="bookmark-index">
      <xsl:apply-templates select="opentopic-index:index.group" mode="bookmark-index"/>
    </xsl:template>
    <xsl:template match="opentopic-index:index.group" mode="bookmark-index">
      <xsl:apply-templates select="opentopic-index:label" mode="bookmark-index"/>
    </xsl:template>
    <xsl:template match="opentopic-index:label" mode="bookmark-index">
      <!-- Letter headings in index are always collapsed, regardless of bookmarkStyle. -->
      <fo:bookmark internal-destination="{generate-id(.)}" starting-state="hide">
          <fo:bookmark-title>
            <xsl:value-of select="."/>
          </fo:bookmark-title>
      </fo:bookmark>
    </xsl:template>

</xsl:stylesheet>