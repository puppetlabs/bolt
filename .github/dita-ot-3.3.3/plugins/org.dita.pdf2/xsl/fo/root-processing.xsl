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

This file is part of the DITA Open Toolkit. 
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:opentopic-i18n="http://www.idiominc.com/opentopic/i18n"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    xmlns:opentopic="http://www.idiominc.com/opentopic"
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    exclude-result-prefixes="opentopic-index opentopic opentopic-i18n opentopic-func dita-ot xs ot-placeholder"
    version="2.0">
    
    <xsl:param name="bookmap-order" select="'discard'" as="xs:string"/>
  
    <xsl:variable name="retain-bookmap-order" select="*[contains(@class,' bookmap/bookmap ')] and $bookmap-order eq 'retain'" as="xs:boolean"/>
    <xsl:variable name="writing-mode" as="xs:string">
      <xsl:variable name="lang" select="if (contains($locale, '_')) then substring-before($locale, '_') else $locale"/>
      <xsl:choose>
        <xsl:when test="some $l in ('ar', 'fa', 'he', 'ps', 'ur') satisfies $l eq $lang">rl</xsl:when>
        <xsl:otherwise>lr</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="mapType" as="xs:string">
        <xsl:choose>
            <xsl:when test="/*[contains(@class, ' bookmap/bookmap ')]">bookmap</xsl:when>
            <xsl:otherwise>ditamap</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="productName">
        <xsl:variable name="mapProdname" select="(/*/opentopic:map//*[contains(@class, ' topic/prodname ')])[1]" as="element()?"/>
        <xsl:choose>
            <xsl:when test="exists($mapProdname)">
                <xsl:apply-templates select="$mapProdname" mode="set-product-name"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Product Name'"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="map" select="//opentopic:map" as="element()?"/>

    <xsl:variable name="topicNumbers">
        <xsl:for-each select="//*[contains(@class, ' topic/topic ')]">
            <topic guid="{generate-id()}">
                <xsl:call-template name="commonattributes"/>
            </topic>
        </xsl:for-each>
    </xsl:variable>

    <xsl:variable name="relatedTopicrefs" select="//*[contains(@class, ' map/reltable ')]//*[contains(@class, ' map/topicref ')]" as="element()*"/>

    <xsl:template match="*[contains(@class, ' topic/prodname ')]" mode="set-product-name">
      <xsl:apply-templates select="." mode="dita-ot:text-only"/>
    </xsl:template>

    <xsl:template name="validateTopicRefs">
        <xsl:apply-templates select="//opentopic:map" mode="topicref-validation"/>
    </xsl:template>

    <xsl:template match="opentopic:map" mode="topicref-validation">
        <xsl:apply-templates mode="topicref-validation"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="topicref-validation">
        <xsl:if test="@href = ''">
          <xsl:call-template name="output-message">
            <xsl:with-param name="id" select="'PDFX004F'"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="@href and @id">
            <xsl:if test="not(@id = '') and empty(key('topic-id', @id))">
              <xsl:call-template name="output-message">
                <xsl:with-param name="id" select="'PDFX005F'"/>
                <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
              </xsl:call-template>
            </xsl:if>
        </xsl:if>
        <xsl:apply-templates mode="topicref-validation"/>
    </xsl:template>

    <xsl:template match="*" mode="topicref-validation"/>

  <xsl:template name="createMetadata">
  <!-- Override in XSL processor specific stylesheets -->
  </xsl:template>
    
  <xsl:template match="/" mode="dita-ot:title-metadata" as="xs:string?">
    <xsl:choose>
      <xsl:when test="exists($map/*[contains(@class, ' bookmap/booktitle ')]/*[contains(@class,' bookmap/mainbooktitle ')])">
        <xsl:value-of>
          <xsl:apply-templates select="$map/*[contains(@class, ' bookmap/booktitle ')]/*[contains(@class,' bookmap/mainbooktitle ')][1]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:when>
      <xsl:when test="exists($map/*[contains(@class,' topic/title ')])">
        <xsl:value-of>
          <xsl:apply-templates select="$map/*[contains(@class,' topic/title ')][1]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:when>
      <xsl:when test="exists(//*[contains(@class, ' map/map ')]/@title)">
        <xsl:value-of select="//*[contains(@class, ' map/map ')]/@title"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of>
          <xsl:apply-templates select="descendant::*[contains(@class, ' topic/topic ')][1]/*[contains(@class, ' topic/title ')]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/" mode="dita-ot:author-metadata" as="xs:string?">
    <xsl:variable name="authorinformation" select="$map/*[contains(@class, ' bookmap/bookmeta ')]/*[contains(@class, ' xnal-d/authorinformation ')]" as="element()*"/>
    <xsl:choose>
      <xsl:when test="exists($authorinformation/descendant::*[contains(@class, ' xnal-d/personname ')])">
        <xsl:for-each select="$authorinformation/descendant::*[contains(@class, ' xnal-d/personname ')][1]">
          <!-- Requires locale specific processing -->
          <xsl:value-of>
            <xsl:apply-templates select="*[contains(@class, ' xnal-d/firstname ')]/node()" mode="dita-ot:text-only"/>
            <xsl:text> </xsl:text>
            <xsl:apply-templates select="*[contains(@class, ' xnal-d/lastname ')]/node()" mode="dita-ot:text-only"/>
          </xsl:value-of>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="exists($authorinformation/descendant::*[contains(@class, ' xnal-d/organizationname ')])">
        <xsl:value-of>
          <xsl:apply-templates select="$authorinformation/descendant::*[contains(@class, ' xnal-d/organizationname ')]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:when>
      <xsl:when test="exists($map/*[contains(@class, ' bookmap/bookmeta ')]/*[contains(@class, ' topic/author ')])">
        <xsl:value-of>
          <xsl:apply-templates select="$map/*[contains(@class, ' bookmap/bookmeta ')]/*[contains(@class, ' topic/author ')]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="/" mode="dita-ot:keywords-metadata" as="xs:string*">
    <xsl:variable name="keywords" select="$map/*[contains(@class, ' bookmap/bookmeta ')]/*[contains(@class, ' topic/keywords ')]/*[contains(@class, 'topic/keyword ')]" as="element()*"/>
    <xsl:for-each select="$keywords">
      <xsl:value-of>
        <xsl:apply-templates select="." mode="dita-ot:text-only"/>
      </xsl:value-of>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="/" mode="dita-ot:subject-metadata" as="xs:string?">
    <xsl:choose>
      <xsl:when test="exists($map/*[contains(@class, ' bookmap/bookmeta ')]/*[contains(@class, ' map/shortdesc ')])">
        <xsl:value-of>
          <xsl:apply-templates select="$map/*[contains(@class, ' bookmap/bookmeta ')]/*[contains(@class, ' map/shortdesc ')]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:when>
      <xsl:when test="exists($map/*[contains(@class, ' topic/shortdesc ')])">
        <xsl:value-of>
          <xsl:apply-templates select="$map/*[contains(@class, ' topic/shortdesc ')]" mode="dita-ot:text-only"/>
        </xsl:value-of>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

    <xsl:template match="/" name="rootTemplate">
        <xsl:call-template name="validateTopicRefs"/>
        <fo:root xsl:use-attribute-sets="__fo__root">
            <xsl:call-template name="createMetadata"/>
            <xsl:call-template name="createLayoutMasters"/>
            <xsl:call-template name="createBookmarks"/>
            <xsl:apply-templates select="*" mode="generatePageSequences"/>
        </fo:root>
    </xsl:template>
  
  <xsl:variable name="map-based-page-sequence-generation" select="true()" as="xs:boolean"/>
  
  <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="generatePageSequences">
    <fo:page-sequence master-reference="ditamap-body-sequence" xsl:use-attribute-sets="page-sequence.body">
      <xsl:call-template name="startPageNumbering"/>
      <xsl:call-template name="insertBodyStaticContents"/>
      <fo:flow flow-name="xsl-region-body">
        <xsl:apply-templates select="." mode="processTopic"/>
      </fo:flow>
    </fo:page-sequence>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="generatePageSequences">
    <xsl:call-template name="createFrontMatter"/>
    <xsl:call-template name="createToc"/>
    <xsl:choose>
      <xsl:when test="$map-based-page-sequence-generation">
        <fo:page-sequence master-reference="ditamap-body-sequence" xsl:use-attribute-sets="page-sequence.body">
          <xsl:call-template name="startPageNumbering"/>
          <xsl:call-template name="insertBodyStaticContents"/>
          <fo:flow flow-name="xsl-region-body">
            <xsl:for-each select="opentopic:map/*[contains(@class, ' map/topicref ')]">
              <xsl:apply-templates select="." mode="generatePageSequenceFromTopicref"/>
            </xsl:for-each>
          </fo:flow>
        </fo:page-sequence>
        <xsl:call-template name="createIndex"/>
      </xsl:when>
      <!-- legacy topic based page-sequence generation -->
      <xsl:otherwise>
        <xsl:apply-templates/>
        
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="createBackCover"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' map/topicref ')]" mode="generatePageSequenceFromTopicref">
    <xsl:variable name="referencedTopic" select="key('topic-id', @id)" as="element()*"/>
    <xsl:choose>
      <xsl:when test="empty($referencedTopic)">
        <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="generatePageSequenceFromTopicref"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$referencedTopic">
          <xsl:apply-templates select="." mode="processTopic"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' bookmap/bookmap ')]" mode="generatePageSequences" priority="10">
    <xsl:call-template name="createFrontMatter"/>
    <xsl:choose>
      <xsl:when test="$map-based-page-sequence-generation">
        <xsl:apply-templates select="opentopic:map/*[contains(@class, ' map/topicref ')]" mode="generatePageSequences"/>
      </xsl:when>
      <!-- legacy topic based page-sequence generation -->
      <xsl:otherwise>
        <xsl:if test="not($retain-bookmap-order)">
          <xsl:apply-templates select="/bookmap/*[contains(@class,' topic/topic ')]" mode="process-notices"/>
          <xsl:call-template name="createToc"/>
        </xsl:if>
        <xsl:apply-templates/>
        <xsl:if test="not($retain-bookmap-order)">
          <xsl:call-template name="createIndex"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="createBackCover"/>
  </xsl:template>
  
  <xsl:template match="*" mode="generatePageSequences" priority="-1">
    <xsl:apply-templates select="*" mode="generatePageSequences"/>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="generatePageSequences" priority="0">
    <xsl:variable name="referencedTopic" select="key('topic-id', @id)" as="element()*"/>
    <xsl:choose>
      <xsl:when test="empty($referencedTopic)">
        <xsl:apply-templates select="*[contains(@class,' map/topicref ')]" mode="generatePageSequences"/>
      </xsl:when>
      <xsl:when test="ancestor::*[contains(@class,' bookmap/frontmatter ')]">
        <!-- TODO: To fit the pattern, this should be in its own match template. But a general match for frontmatter/*
             conflicts with priority of existing rules (e.g., preface); changing priorities would
             break customizations. --> 
        <xsl:for-each select="$referencedTopic">
          <xsl:call-template name="processFrontMatterTopic"/>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$referencedTopic">
          <xsl:call-template name="processTopicSimple"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/frontmatter ') or
                         contains(@class, ' bookmap/backmatter ') or
                         contains(@class, ' bookmap/booklists ')]" mode="generatePageSequences">
    <xsl:apply-templates select="*" mode="generatePageSequences"/>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/chapter ')]" mode="generatePageSequences">
    <xsl:variable name="referencedTopic" select="key('topic-id', @id)" as="element()*"/>
    <xsl:choose>
      <xsl:when test="empty($referencedTopic)">
        <xsl:apply-templates select="*[contains(@class,' map/topicref ')]" mode="generatePageSequences"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$referencedTopic">
          <xsl:call-template name="processTopicChapter"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/appendix ')]" mode="generatePageSequences">
    <xsl:variable name="referencedTopic" select="key('topic-id', @id)" as="element()*"/>
    <xsl:choose>
      <xsl:when test="empty($referencedTopic)">
        <xsl:apply-templates select="*[contains(@class,' map/topicref ')]" mode="generatePageSequences"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$referencedTopic">
          <xsl:call-template name="processTopicAppendix"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/preface ')]" mode="generatePageSequences">
    <xsl:variable name="referencedTopic" select="key('topic-id', @id)" as="element()*"/>
    <xsl:choose>
      <xsl:when test="empty($referencedTopic)">
        <xsl:apply-templates select="*[contains(@class,' map/topicref ')]" mode="generatePageSequences"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$referencedTopic">
            <xsl:call-template name="processTopicPreface"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/appendices ')]" mode="generatePageSequences">
    <xsl:variable name="referencedTopic" select="key('topic-id', @id)" as="element()*"/>
    <xsl:choose>
      <xsl:when test="empty($referencedTopic)">
        <xsl:apply-templates select="*[contains(@class, ' bookmap/appendix ')]" mode="generatePageSequences"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$referencedTopic">
            <xsl:call-template name="processTopicAppendices"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/part ')]" mode="generatePageSequences">
    <!-- Merge process generates placeholder for <part> with no title, no topic -->
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:call-template name="processTopicPart"/>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/figurelist ')]" mode="generatePageSequences">
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:choose>
        <xsl:when test="self::ot-placeholder:figurelist">
          <xsl:call-template name="createFigureList"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="processTopicSimple"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/tablelist ')]" mode="generatePageSequences">
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:choose>
        <xsl:when test="self::ot-placeholder:tablelist">
          <xsl:call-template name="createTableList"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="processTopicSimple"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/indexlist ')]" mode="generatePageSequences">
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:choose>
        <xsl:when test="self::ot-placeholder:indexlist">
          <xsl:call-template name="createIndex"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="processIndexList"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/toc ')]" mode="generatePageSequences">
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:choose>
        <xsl:when test="self::ot-placeholder:toc">
          <xsl:call-template name="createToc"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="processTocList"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/glossarylist ')]" mode="generatePageSequences">
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:choose>
        <xsl:when test="self::ot-placeholder:glossarylist">
          <xsl:call-template name="createGlossary"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="processTopicSimple"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' bookmap/notices ')]" mode="generatePageSequences">
    <xsl:for-each select="key('topic-id', @id)">
      <xsl:call-template name="processTopicNotices"/>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="process-notices">
    <xsl:variable name="topicType">
      <xsl:call-template name="determineTopicType"/>
    </xsl:variable>
    <xsl:if test="$topicType = 'topicNotices'">
      <xsl:call-template name="processTopicNotices"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:apply-templates/>
  </xsl:template>

</xsl:stylesheet>
