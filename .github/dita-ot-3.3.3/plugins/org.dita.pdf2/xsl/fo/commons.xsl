<?xml version='1.0'?>

<!--
Copyright ? 2004-2006 by Idiom Technologies, Inc. All rights reserved.
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
    xmlns:dita2xslfo="http://dita-ot.sourceforge.net/ns/200910/dita2xslfo"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
    exclude-result-prefixes="dita-ot ot-placeholder opentopic opentopic-index opentopic-func dita2xslfo xs"
    version="2.0">

    <!-- FIXME these imports should be moved to shell -->
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/topic.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/concept.xsl"/>

    <xsl:key name="id" match="*[@id]" use="@id"/>
    <xsl:key name="map-id"
             match="opentopic:map//*[@id][empty(ancestor::*[contains(@class, ' map/reltable ')])]"
             use="@id"/>
    <xsl:key name="topic-id"
             match="*[@id][contains(@class, ' topic/topic ')] |
                    ot-placeholder:*[@id]"
             use="@id"/>
    <xsl:key name="class" match="*[@class]" use="tokenize(@class, ' ')"/>
    <xsl:key name="fnById" match="*[contains(@class, ' topic/fn ')]" use="@id"/>

    <!--
    A key with all elements that need to be numbered.

    To get the number of an element using this key, you can use the << node
    comparison operator in XPath 2 to get all elements in the key that appear
    before the current element in the tree. For example, to get the number of
    topic/fig elements before the current element, you would do something like:

      <xsl:value-of select="count(key('enumerableByClass', 'topic/fig')[. &lt;&lt; current()])"/>

    This is much faster than using the preceding:: axis and somewhat faster than
    using the <xsl:number> element.
    -->
    <xsl:key name="enumerableByClass"
             match="*[contains(@class, ' topic/fig ')][*[contains(@class, ' topic/title ')]] |
                    *[contains(@class, ' topic/table ')][*[contains(@class, ' topic/title ')]] |
                    *[contains(@class,' topic/fn ') and empty(@callout)]"
              use="tokenize(@class, ' ')"/>

    <!-- Deprecated since 2.3 -->
    <xsl:variable name="msgprefix" select="'PDFX'"/>

    <xsl:variable name="id.toc" select="'ID_TOC_00-0F-EA-40-0D-4D'"/>
    <xsl:variable name="id.index" select="'ID_INDEX_00-0F-EA-40-0D-4D'"/>
    <xsl:variable name="id.lot" select="'ID_LOT_00-0F-EA-40-0D-4D'"/>
    <xsl:variable name="id.lof" select="'ID_LOF_00-0F-EA-40-0D-4D'"/>
    <xsl:variable name="id.glossary" select="'ID_GLOSSARY_00-0F-EA-40-0D-4D'"/>

    <xsl:variable name="root" select="/" as="document-node()"/>

    <!--  In order to not process any data under opentopic:map  -->
    <xsl:template match="opentopic:map"/>

    <!-- get the max chars for shortdesc-->
    <xsl:variable name="maxCharsInShortDesc" as="xs:integer">
        <xsl:call-template name="getMaxCharsForShortdescKeep"/>
    </xsl:variable>
 
    <xsl:template name="startPageNumbering" as="attribute()*">
        <!--BS: uncomment if you need reset page numbering at first chapter-->
<!--
        <xsl:variable name="id" select="ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id"/>
        <xsl:variable name="mapTopic" select="key('map-id', $id)"/>

        <xsl:if test="not(($mapTopic/preceding::*[contains(@class, ' bookmap/chapter ') or contains(@class, ' bookmap/part ')])
            or ($mapTopic/ancestor::*[contains(@class, ' bookmap/chapter ') or contains(@class, ' bookmap/part ')]))">
            <xsl:attribute name="initial-page-number">1</xsl:attribute>
        </xsl:if>
-->
    </xsl:template>

    <xsl:template match="*" mode="commonTopicProcessing">
      <xsl:if test="empty(ancestor::*[contains(@class, ' topic/topic ')])">
        <fo:marker marker-class-name="current-topic-number">
          <xsl:variable name="topicref" 
            select="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')]/@id)[1]" 
            as="element()?"
          />
          <xsl:for-each select="$topicref">
            <xsl:apply-templates select="." mode="topicTitleNumber"/>
          </xsl:for-each>
        </fo:marker>
      </xsl:if>
      <fo:block>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="flag-attributes"/>
        <xsl:apply-templates select="." mode="customTopicMarker"/>
        <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
        <xsl:apply-templates select="*[contains(@class, ' topic/prolog ')]"/>
          <xsl:apply-templates select="* except(*[contains(@class, ' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop ') or
              contains(@class, ' topic/prolog ') or contains(@class, ' topic/topic ')])"/>
        <!--xsl:apply-templates select="." mode="buildRelationships"/-->
        <xsl:apply-templates select="*[contains(@class,' topic/topic ')]"/>
        <xsl:apply-templates select="." mode="topicEpilog"/>
      </fo:block>
    </xsl:template>
    
    <!-- Hook that allows extra markers at the start of any topic block -->
    <xsl:template match="*" mode="customTopicMarker"/>
    
    <!-- Hook that allows extra markers at the start of any topic block -->
    <xsl:template match="*" mode="customTopicAnchor"/>

    <!-- Hook that allows common end-of-topic processing (after nested topics). -->
    <xsl:template match="*" mode="topicEpilog">
      
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/topic ')]">
        <xsl:variable name="topicType" as="xs:string">
            <xsl:call-template name="determineTopicType"/>
        </xsl:variable>

        <xsl:choose>
            <xsl:when test="$topicType = 'topicChapter'">
                <xsl:call-template name="processTopicChapter"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicAppendix'">
                <xsl:call-template name="processTopicAppendix"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicAppendices'">
                <xsl:call-template name="processTopicAppendices"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicPart'">
                <xsl:call-template name="processTopicPart"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicPreface'">
                <xsl:call-template name="processTopicPreface"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicNotices'">
                <xsl:if test="$retain-bookmap-order">
                  <xsl:call-template name="processTopicNotices"/>
                </xsl:if>
            </xsl:when>
            <xsl:when test="$topicType = 'topicTocList'">
              <xsl:call-template name="processTocList"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicIndexList'">
              <xsl:call-template name="processIndexList"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicFrontMatter'">
              <xsl:call-template name="processFrontMatterTopic"/>
            </xsl:when>
            <xsl:when test="$topicType = 'topicSimple'">
              <xsl:call-template name="processTopicSimple"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="processUnknowTopic">
                    <xsl:with-param name="topicType" select="$topicType"/>
                </xsl:apply-templates>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

  <xsl:template match="*" mode="processUnknowTopic"
                name="processTopicSimple">
    <xsl:param name="topicType"/>
    <xsl:variable name="page-sequence-reference" select="if ($mapType = 'bookmap') then 'body-sequence' else 'ditamap-body-sequence'"/>
    <xsl:choose>
      <xsl:when test="empty(ancestor::*[contains(@class,' topic/topic ')]) and empty(ancestor::ot-placeholder:glossarylist)">
        <fo:page-sequence master-reference="{$page-sequence-reference}" xsl:use-attribute-sets="page-sequence.body">
          <xsl:call-template name="startPageNumbering"/>
          <xsl:call-template name="insertBodyStaticContents"/>
          <fo:flow flow-name="xsl-region-body">
            <xsl:apply-templates select="." mode="processTopic"/>
          </fo:flow>
        </fo:page-sequence>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="processTopic"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="insertTopicHeaderMarker">
    <xsl:param name="marker-class-name" as="xs:string">current-header</xsl:param>

    <fo:marker marker-class-name="{$marker-class-name}">
      <xsl:apply-templates select="." mode="insertTopicHeaderMarkerContents"/>
    </fo:marker>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="insertTopicHeaderMarkerContents">
    <xsl:apply-templates select="*[contains(@class,' topic/title ')]" mode="getTitle"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/title ')]" mode="insertTopicHeaderMarkerContents">
    <xsl:apply-templates select="." mode="getTitle"/>
  </xsl:template>

    <!--  Bookmap Chapter processing  -->
    <xsl:template name="processTopicChapter">
        <xsl:variable name="expectedChapterContext" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="empty(parent::*[contains(@class,' topic/topic ')])"><xsl:sequence select="true()"/></xsl:when>
                <xsl:when test="count(ancestor::*[contains(@class,' topic/topic ')]) = 1 and 
                    contains((key('map-id',parent::*/@id)[1])/@class,' bookmap/part ')"><xsl:sequence select="true()"/></xsl:when>
                <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$expectedChapterContext">
                <fo:page-sequence master-reference="body-sequence" xsl:use-attribute-sets="page-sequence.body">
                    <xsl:call-template name="startPageNumbering"/>
                    <xsl:call-template name="insertBodyStaticContents"/>
                    <fo:flow flow-name="xsl-region-body">
                        <xsl:apply-templates select="." mode="processTopicChapterInsideFlow"/>
                    </fo:flow>
                </fo:page-sequence>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="processTopicChapterInsideFlow"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="*" mode="processTopicChapterInsideFlow">
        <fo:block xsl:use-attribute-sets="topic">
            <xsl:call-template name="commonattributes"/>
            <xsl:variable name="level" as="xs:integer">
              <xsl:apply-templates select="." mode="get-topic-level"/>
            </xsl:variable>
            <xsl:if test="$level eq 1">
                <fo:marker marker-class-name="current-topic-number">
                  <xsl:variable name="topicref" 
                    select="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id)[1]" 
                    as="element()?"/>
                  <xsl:for-each select="$topicref">
                    <xsl:apply-templates select="." mode="topicTitleNumber"/>
                  </xsl:for-each>
                </fo:marker>
                <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
            </xsl:if>
            <xsl:apply-templates select="." mode="customTopicMarker"/>

            <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>

            <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
                <xsl:with-param name="type" select="'chapter'"/>
            </xsl:apply-templates>

            <fo:block xsl:use-attribute-sets="topic.title">
                <xsl:apply-templates select="." mode="customTopicAnchor"/>
                <xsl:call-template name="pullPrologIndexTerms"/>
                <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                <xsl:for-each select="*[contains(@class,' topic/title ')]">
                    <xsl:apply-templates select="." mode="getTitle"/>
                </xsl:for-each>
            </fo:block>

            <xsl:choose>
              <xsl:when test="$chapterLayout='BASIC'">
                  <xsl:apply-templates select="* except(*[contains(@class, ' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop ') or
                      contains(@class, ' topic/prolog ') or contains(@class, ' topic/topic ')])"/>
                  <!--xsl:apply-templates select="." mode="buildRelationships"/-->
              </xsl:when>
              <xsl:otherwise>
                  <xsl:apply-templates select="." mode="createMiniToc"/>
              </xsl:otherwise>
            </xsl:choose>

            <xsl:apply-templates select="*[contains(@class,' topic/topic ')]"/>
            <xsl:call-template name="pullPrologIndexTerms.end-range"/>
        </fo:block>
    </xsl:template>

    <!--  Bookmap Appendix processing  -->
    <xsl:template name="processTopicAppendix">
        <xsl:variable name="expectedAppContext" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="empty(parent::*[contains(@class,' topic/topic ')])"><xsl:sequence select="true()"/></xsl:when>
                <xsl:when test="count(ancestor::*[contains(@class,' topic/topic ')]) = 1 and 
                    contains(key('map-id',parent::*/@id)[1]/@class,' bookmap/appendices ')"><xsl:sequence select="true()"/></xsl:when>
                <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$expectedAppContext">
                <fo:page-sequence master-reference="body-sequence" xsl:use-attribute-sets="page-sequence.appendix">
                    <xsl:call-template name="startPageNumbering"/>
                    <xsl:call-template name="insertBodyStaticContents"/>
                    <fo:flow flow-name="xsl-region-body">
                        <xsl:apply-templates select="." mode="processTopicAppendixInsideFlow"/>
                    </fo:flow>
                </fo:page-sequence>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="processTopicAppendixInsideFlow"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="*" mode="processTopicAppendixInsideFlow">
        <fo:block xsl:use-attribute-sets="topic">
            <xsl:call-template name="commonattributes"/>
            <xsl:variable name="level" as="xs:integer">
              <xsl:apply-templates select="." mode="get-topic-level"/>
            </xsl:variable>
            <xsl:if test="$level eq 1">
                <fo:marker marker-class-name="current-topic-number">
                  <xsl:variable name="topicref" 
                    select="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id)[1]" 
                    as="element()?"/>
                    <xsl:for-each select="$topicref">
                      <xsl:apply-templates select="." mode="topicTitleNumber"/>
                    </xsl:for-each>
                </fo:marker>
                <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
            </xsl:if>
            <xsl:apply-templates select="." mode="customTopicMarker"/>

            <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>

            <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
                <xsl:with-param name="type" select="'appendix'"/>
            </xsl:apply-templates>

            <fo:block xsl:use-attribute-sets="topic.title">
                <xsl:apply-templates select="." mode="customTopicAnchor"/>
                <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                <xsl:call-template name="pullPrologIndexTerms"/>
                <xsl:for-each select="*[contains(@class,' topic/title ')]">
                    <xsl:apply-templates select="." mode="getTitle"/>
                </xsl:for-each>
            </fo:block>

            <xsl:choose>
              <xsl:when test="$appendixLayout='BASIC'">
                  <xsl:apply-templates select="* except(*[contains(@class, ' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop ') or
                      contains(@class, ' topic/prolog ') or contains(@class, ' topic/topic ')])"/>
                  <!--xsl:apply-templates select="." mode="buildRelationships"/-->
              </xsl:when>
              <xsl:otherwise>
                  <xsl:apply-templates select="." mode="createMiniToc"/>
              </xsl:otherwise>
            </xsl:choose>

            <xsl:apply-templates select="*[contains(@class,' topic/topic ')]"/>
            <xsl:call-template name="pullPrologIndexTerms.end-range"/>
        </fo:block>
    </xsl:template>

  <!--  Bookmap appendices processing  -->
  <xsl:template name="processTopicAppendices">
      <xsl:variable name="expectedAppsContext" as="xs:boolean" 
          select="empty(parent::*[contains(@class,' topic/topic ')])"/>
      <xsl:choose>
          <xsl:when test="$expectedAppsContext">
              <fo:page-sequence master-reference="body-sequence" xsl:use-attribute-sets="page-sequence.appendix">
                  <xsl:call-template name="startPageNumbering"/>
                  <xsl:call-template name="insertBodyStaticContents"/>
                  <fo:flow flow-name="xsl-region-body">
                      <xsl:apply-templates select="." mode="processTopicAppendicesInsideFlow"/>
                  </fo:flow>
              </fo:page-sequence>
          </xsl:when>
          <xsl:otherwise>
              <xsl:apply-templates select="." mode="processTopicAppendicesInsideFlow"/>
          </xsl:otherwise>
      </xsl:choose>
      <xsl:for-each select="*[contains(@class,' topic/topic ')]">
          <xsl:variable name="topicType" as="xs:string">
              <xsl:call-template name="determineTopicType"/>
          </xsl:variable>
          <xsl:if test="not($topicType = 'topicSimple')">
              <xsl:apply-templates select="."/>
          </xsl:if>
      </xsl:for-each>
  </xsl:template>
  <xsl:template match="*" mode="processTopicAppendicesInsideFlow">
    <fo:block xsl:use-attribute-sets="topic">
      <xsl:call-template name="commonattributes"/>
      <xsl:if test="empty(ancestor::*[contains(@class, ' topic/topic ')])">
        <fo:marker marker-class-name="current-topic-number">
          <xsl:variable name="topicref" 
            select="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id)[1]" 
            as="element()?"
          />
          <xsl:for-each select="$topicref">
            <xsl:apply-templates select="." mode="topicTitleNumber"/>
          </xsl:for-each>
        </fo:marker>
        <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="customTopicMarker"/>
          
      <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>
          
      <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
        <xsl:with-param name="type" select="'appendices'"/>
      </xsl:apply-templates>
          
      <fo:block xsl:use-attribute-sets="topic.title">
        <xsl:apply-templates select="." mode="customTopicAnchor"/>
        <xsl:call-template name="pullPrologIndexTerms"/>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
        <xsl:for-each select="*[contains(@class,' topic/title ')]">
          <xsl:apply-templates select="." mode="getTitle"/>
        </xsl:for-each>
      </fo:block>
          
      <xsl:choose>
        <xsl:when test="$appendicesLayout='BASIC'">
          <xsl:apply-templates select="* except(*[contains(@class, ' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop ') or
                contains(@class, ' topic/prolog ') or contains(@class, ' topic/topic ')])"/>
          <!--xsl:apply-templates select="." mode="buildRelationships"/-->
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="createMiniToc"/>
        </xsl:otherwise>
      </xsl:choose>
                    
      <xsl:for-each select="*[contains(@class,' topic/topic ')]">
        <xsl:variable name="topicType" as="xs:string">
          <xsl:call-template name="determineTopicType"/>
        </xsl:variable>
        <xsl:if test="$topicType = 'topicSimple'">
          <xsl:apply-templates select="."/>
        </xsl:if>
      </xsl:for-each>
      <xsl:call-template name="pullPrologIndexTerms.end-range"/>
    </fo:block>
  </xsl:template>

    <!--  Bookmap Part processing  -->
    <xsl:template name="processTopicPart">
        <xsl:variable name="expectedPartContext" as="xs:boolean" 
            select="empty(parent::*[contains(@class,' topic/topic ')])"/>
        <xsl:choose>
            <xsl:when test="$expectedPartContext">
                <fo:page-sequence master-reference="body-sequence" xsl:use-attribute-sets="page-sequence.part">
                    <xsl:call-template name="startPageNumbering"/>
                    <xsl:call-template name="insertBodyStaticContents"/>
                    <fo:flow flow-name="xsl-region-body">
                        <xsl:apply-templates select="." mode="processTopicPartInsideFlow"/>
                    </fo:flow>
                </fo:page-sequence>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="processTopicPartInsideFlow"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:for-each select="*[contains(@class,' topic/topic ')]">
            <xsl:variable name="topicType" as="xs:string">
                <xsl:call-template name="determineTopicType"/>
            </xsl:variable>
            <xsl:if test="not($topicType = 'topicSimple')">
                <xsl:apply-templates select="."/>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>
    <xsl:template match="*" mode="processTopicPartInsideFlow">
        <fo:block xsl:use-attribute-sets="topic">
            <xsl:call-template name="commonattributes"/>
            <xsl:if test="empty(ancestor::*[contains(@class, ' topic/topic ')])">
                <fo:marker marker-class-name="current-topic-number">
                  <xsl:variable name="topicref" 
                    select="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id)[1]" 
                    as="element()?"
                  />
                  <xsl:for-each select="$topicref">
                    <xsl:apply-templates select="." mode="topicTitleNumber"/>
                  </xsl:for-each>
                </fo:marker>
                <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
            </xsl:if>
            <xsl:apply-templates select="." mode="customTopicMarker"/>

            <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>

            <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
                <xsl:with-param name="type" select="'part'"/>
            </xsl:apply-templates>

            <fo:block xsl:use-attribute-sets="topic.title">
                <xsl:apply-templates select="." mode="customTopicAnchor"/>
                <xsl:call-template name="pullPrologIndexTerms"/>
                <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                <xsl:for-each select="*[contains(@class,' topic/title ')]">
                    <xsl:apply-templates select="." mode="getTitle"/>
                </xsl:for-each>
            </fo:block>

            <xsl:choose>
              <xsl:when test="$partLayout='BASIC'">
                  <xsl:apply-templates select="* except(*[contains(@class, ' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop ') or
                      contains(@class, ' topic/prolog ') or contains(@class, ' topic/topic ')])"/>
                  <!--xsl:apply-templates select="." mode="buildRelationships"/-->
              </xsl:when>
              <xsl:otherwise>
                  <xsl:apply-templates select="." mode="createMiniToc"/>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:for-each select="*[contains(@class,' topic/topic ')]">
                <xsl:variable name="topicType" as="xs:string">
                    <xsl:call-template name="determineTopicType"/>
                </xsl:variable>
                <xsl:if test="$topicType = 'topicSimple'">
                    <xsl:apply-templates select="."/>
                </xsl:if>
            </xsl:for-each>
            <xsl:call-template name="pullPrologIndexTerms.end-range"/>
        </fo:block>
    </xsl:template>

    <xsl:template name="processTopicNotices">
        <xsl:variable name="atts" as="element()">
            <xsl:choose>
                <xsl:when test="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id)/ancestor::*[contains(@class,' bookmap/backmatter ')]">
                    <dummy xsl:use-attribute-sets="page-sequence.backmatter.notice"/> 
                </xsl:when>
                <xsl:otherwise>
                    <dummy xsl:use-attribute-sets="page-sequence.notice"/> 
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <fo:page-sequence master-reference="body-sequence">
            <xsl:copy-of select="$atts/@*"/>
            <xsl:call-template name="startPageNumbering"/>
            <xsl:call-template name="insertPrefaceStaticContents"/>
            <fo:flow flow-name="xsl-region-body">
                <fo:block xsl:use-attribute-sets="topic">
                    <xsl:call-template name="commonattributes"/>
                    <xsl:if test="empty(ancestor::*[contains(@class, ' topic/topic ')])">
                        <fo:marker marker-class-name="current-topic-number">
                          <xsl:variable name="topicref" 
                            select="key('map-id', ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id)[1]"
                            as="element()?"
                          />
                          <xsl:for-each select="$topicref">
                            <xsl:apply-templates select="." mode="topicTitleNumber"/>
                          </xsl:for-each>
                        </fo:marker>
                        <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
                    </xsl:if>
                    <xsl:apply-templates select="." mode="customTopicMarker"/>

                    <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>

                    <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
                        <xsl:with-param name="type" select="'notices'"/>
                    </xsl:apply-templates>

                    <fo:block xsl:use-attribute-sets="topic.title">
                        <xsl:apply-templates select="." mode="customTopicAnchor"/>
                        <xsl:call-template name="pullPrologIndexTerms"/>
                        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                        <xsl:for-each select="*[contains(@class,' topic/title ')]">
                            <xsl:apply-templates select="." mode="getTitle"/>
                        </xsl:for-each>
                    </fo:block>

                    <xsl:choose>
                      <xsl:when test="$noticesLayout='BASIC'">
                          <xsl:apply-templates select="* except(*[contains(@class, ' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop ') or
                              contains(@class, ' topic/prolog ') or contains(@class, ' topic/topic ')])"/>
                          <!--xsl:apply-templates select="." mode="buildRelationships"/-->
                      </xsl:when>
                      <xsl:otherwise>
                          <xsl:apply-templates select="." mode="createMiniToc"/>
                      </xsl:otherwise>
                    </xsl:choose>

                    <xsl:apply-templates select="*[contains(@class,' topic/topic ')]"/>
                    <xsl:call-template name="pullPrologIndexTerms.end-range"/>
                </fo:block>
            </fo:flow>
        </fo:page-sequence>
   </xsl:template>


    <!-- Deprecated in 3.0: use mode="insertChapterFirstpageStaticContent" -->
    <xsl:template name="processFrontMatterTopic">
        <xsl:variable name="expectedFMContext" as="xs:boolean" 
            select="empty(parent::*[contains(@class,' topic/topic ')])"/>
        <xsl:choose>
            <xsl:when test="$expectedFMContext">
                <fo:page-sequence master-reference="body-sequence" xsl:use-attribute-sets="page-sequence.frontmatter">
                    <!-- Ideally would use existing template "insertFrontMatterStaticContents". Using "insertBodyStaticContents"
                  for compatibility with 2.3 and earlier; front matter version drops headers, page numbers. -->
                    <xsl:call-template name="insertBodyStaticContents"/>
                    <fo:flow flow-name="xsl-region-body">
                        <xsl:apply-templates select="." mode="processTopicFrontMatterInsideFlow"/>
                    </fo:flow>
                </fo:page-sequence>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="processTopicFrontMatterInsideFlow"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="*" mode="processTopicFrontMatterInsideFlow">
                 <fo:block xsl:use-attribute-sets="topic">
                     <xsl:call-template name="commonattributes"/>
                     <xsl:if test="not(ancestor::*[contains(@class, ' topic/topic ')])">
                         <fo:marker marker-class-name="current-topic-number">
                             <xsl:number format="1"/>
                         </fo:marker>
                         <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
                     </xsl:if>
                     <xsl:apply-templates select="." mode="customTopicMarker"/>
                     <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>
                     <fo:block xsl:use-attribute-sets="topic.title">
                         <xsl:attribute name="id">
                             <xsl:call-template name="generate-toc-id"/>
                         </xsl:attribute>
                         <xsl:apply-templates select="." mode="customTopicAnchor"/>
                         <xsl:call-template name="pullPrologIndexTerms"/>
                         <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                         <xsl:for-each select="child::*[contains(@class,' topic/title ')]">
                             <xsl:apply-templates select="." mode="getTitle"/>
                         </xsl:for-each>
                     </fo:block>
                     <xsl:apply-templates select="*[not(contains(@class,' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop '))]"/>
                 </fo:block>
   </xsl:template>

    <xsl:template name="insertChapterFirstpageStaticContent">
      <xsl:param name="type" as="xs:string"/>
      <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
        <xsl:with-param name="type" select="$type" as="xs:string"/>
      </xsl:apply-templates>
    </xsl:template>

   <xsl:template match="*" mode="insertChapterFirstpageStaticContent">
        <xsl:param name="type" as="xs:string"/>
        <fo:block>
            <xsl:attribute name="id">
                <xsl:call-template name="generate-toc-id"/>
            </xsl:attribute>
            <xsl:choose>
                <xsl:when test="$type = 'chapter'">
                    <fo:block xsl:use-attribute-sets="__chapter__frontmatter__name__container">
                        <xsl:call-template name="getVariable">
                            <xsl:with-param name="id" select="'Chapter with number'"/>
                            <xsl:with-param name="params">
                                <number>
                                    <fo:block xsl:use-attribute-sets="__chapter__frontmatter__number__container">
                                        <xsl:apply-templates select="key('map-id', @id)[1]" mode="topicTitleNumber"/>
                                    </fo:block>
                                </number>
                            </xsl:with-param>
                        </xsl:call-template>
                    </fo:block>
                </xsl:when>
                <xsl:when test="$type = 'appendix'">
                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__name__container">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Appendix with number'"/>
                                <xsl:with-param name="params">
                                    <number>
                                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__number__container">
                                            <xsl:apply-templates select="key('map-id', @id)[1]" mode="topicTitleNumber"/>
                                        </fo:block>
                                    </number>
                                </xsl:with-param>
                            </xsl:call-template>
                        </fo:block>
                </xsl:when>
              <xsl:when test="$type = 'appendices'">
                <fo:block xsl:use-attribute-sets="__chapter__frontmatter__name__container">
                  <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Appendix with number'"/>
                    <xsl:with-param name="params">
                      <number>
                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__number__container">
                          <xsl:text>&#xA0;</xsl:text>
                        </fo:block>
                      </number>
                    </xsl:with-param>
                  </xsl:call-template>
                </fo:block>
              </xsl:when>
                <xsl:when test="$type = 'part'">
                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__name__container">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Part with number'"/>
                                <xsl:with-param name="params">
                                    <number>
                                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__number__container">
                                            <xsl:apply-templates select="key('map-id', @id)[1]" mode="topicTitleNumber"/>
                                        </fo:block>
                                    </number>
                                </xsl:with-param>
                            </xsl:call-template>
                        </fo:block>
                </xsl:when>
                <xsl:when test="$type = 'preface'">
                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__name__container">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Preface title'"/>
                            </xsl:call-template>
                        </fo:block>
                </xsl:when>
                <xsl:when test="$type = 'notices'">
                        <fo:block xsl:use-attribute-sets="__chapter__frontmatter__name__container">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Notices title'"/>
                            </xsl:call-template>
                        </fo:block>
                </xsl:when>
            </xsl:choose>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' bookmap/chapter ')] |
                         opentopic:map/*[contains(@class, ' map/topicref ')]" mode="topicTitleNumber" priority="-1">
      <xsl:variable name="chapters">
        <xsl:document>
          <xsl:for-each select="$map/descendant::*[contains(@class, ' bookmap/chapter ')]">
            <xsl:sequence select="."/>
          </xsl:for-each>
        </xsl:document>
      </xsl:variable>
      <xsl:for-each select="$chapters/*[current()/@id = @id]">
        <xsl:number format="1" count="*[contains(@class, ' bookmap/chapter ')]"/>
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' bookmap/appendix ')]" mode="topicTitleNumber">
      <xsl:number format="A" count="*[contains(@class, ' bookmap/appendix ')]"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' bookmap/part ')]" mode="topicTitleNumber">
      <xsl:number format="I" count="*[contains(@class, ' bookmap/part ')]"/>
    </xsl:template>

    <xsl:template match="*" mode="topicTitleNumber" priority="-10">
      <!--xsl:message>No topicTitleNumber mode template for <xsl:value-of select="name()"/></xsl:message-->
    </xsl:template>

    <xsl:template match="*" mode="createMiniToc">
        <fo:table xsl:use-attribute-sets="__toc__mini__table">
            <fo:table-column xsl:use-attribute-sets="__toc__mini__table__column_1"/>
            <fo:table-column xsl:use-attribute-sets="__toc__mini__table__column_2"/>
            <fo:table-body xsl:use-attribute-sets="__toc__mini__table__body">
                <fo:table-row>
                    <fo:table-cell>
                        <fo:block xsl:use-attribute-sets="__toc__mini">
                            <xsl:if test="*[contains(@class, ' topic/topic ')]">
                                <fo:block xsl:use-attribute-sets="__toc__mini__header">
                                    <xsl:call-template name="getVariable">
                                        <xsl:with-param name="id" select="'Mini Toc'"/>
                                    </xsl:call-template>
                                </fo:block>
                                <fo:list-block xsl:use-attribute-sets="__toc__mini__list">
                                    <xsl:apply-templates select="*[contains(@class, ' topic/topic ')]" mode="in-this-chapter-list"/>
                                </fo:list-block>
                            </xsl:if>
                        </fo:block>
                    </fo:table-cell>
                    <fo:table-cell xsl:use-attribute-sets="__toc__mini__summary">
                        <!--Really, it would be better to just apply-templates, but the attribute sets for shortdesc, body
                        and abstract might indent the text.  Here, the topic body is in a table cell, and should
                        not be indented, so each element is handled specially.-->
                        <fo:block>
                            <xsl:apply-templates select="*[contains(@class,' topic/titlealts ')]"/>
                            <xsl:if test="*[contains(@class,' topic/shortdesc ')
                                  or contains(@class, ' topic/abstract ')]/node()">
                              <fo:block xsl:use-attribute-sets="p">
                                <xsl:apply-templates select="*[contains(@class,' topic/shortdesc ')
                                  or contains(@class, ' topic/abstract ')]/node()"/>
                              </fo:block>
                            </xsl:if>
                            <xsl:apply-templates select="*[contains(@class,' topic/body ')]/*"/>
                            <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]"/>

                            <xsl:if test="*[contains(@class,' topic/related-links ')]//
                                          *[contains(@class,' topic/link ')][not(@role) or @role!='child']">
                                <xsl:apply-templates select="*[contains(@class,' topic/related-links ')]"/>
                            </xsl:if>

            </fo:block>
                    </fo:table-cell>
                </fo:table-row>
            </fo:table-body>
        </fo:table>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="in-this-chapter-list">
        <fo:list-item xsl:use-attribute-sets="ul.li">
            <fo:list-item-label xsl:use-attribute-sets="ul.li__label">
                <fo:block xsl:use-attribute-sets="ul.li__label__content">
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Unordered List bullet'"/>
                    </xsl:call-template>
                </fo:block>
            </fo:list-item-label>

            <fo:list-item-body xsl:use-attribute-sets="ul.li__body">
                <fo:block xsl:use-attribute-sets="ul.li__content">
                    <fo:basic-link internal-destination="{@id}" xsl:use-attribute-sets="xref">
                        <xsl:value-of select="*[contains(@class, ' topic/title ')]"/>
                    </fo:basic-link>
                </fo:block>
            </fo:list-item-body>
        </fo:list-item>
    </xsl:template>

    <!-- BS: Template owerwrited to define new topic types (List's),
    to create special processing for any of list you should use <template name="processUnknowTopic"/>
    example below.-->
    <xsl:template name="determineTopicType">
      <xsl:variable name="foundTopicType" as="xs:string?">
        <xsl:variable name="topic" select="ancestor-or-self::*[contains(@class, ' topic/topic ')][1]"/>
        <xsl:variable name="id" select="$topic/@id"/>
        <xsl:variable name="mapTopics" select="key('map-id', $id)[1]" as="element()?"/>
        <xsl:apply-templates select="$mapTopics" mode="determineTopicType"/>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="exists($foundTopicType) and $foundTopicType != ''">
          <xsl:value-of select="$foundTopicType"/>
        </xsl:when>
        <xsl:otherwise>topicSimple</xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="determineTopicType">
        <!-- Default, when not matching a bookmap type, is topicSimple -->
        <xsl:text>topicSimple</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/chapter ')]" mode="determineTopicType">
        <xsl:text>topicChapter</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/appendix ')]" mode="determineTopicType">
        <xsl:text>topicAppendix</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/preface ')]" mode="determineTopicType">
        <xsl:text>topicPreface</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/appendices ')]" mode="determineTopicType">
      <xsl:text>topicAppendices</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/part ')]" mode="determineTopicType">
        <xsl:text>topicPart</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/abbrevlist ')]" mode="determineTopicType">
        <xsl:text>topicAbbrevList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/bibliolist ')]" mode="determineTopicType">
        <xsl:text>topicBiblioList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/booklist ')]" mode="determineTopicType">
        <xsl:text>topicBookList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/figurelist ')]" mode="determineTopicType">
        <xsl:text>topicFigureList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/indexlist ')]" mode="determineTopicType">
        <xsl:text>topicIndexList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/toc ')]" mode="determineTopicType">
        <xsl:text>topicTocList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/glossarylist ')]" mode="determineTopicType">
        <xsl:text>topicGlossaryList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/trademarklist ')]" mode="determineTopicType">
        <xsl:text>topicTradeMarkList</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' bookmap/notices ')]" mode="determineTopicType">
        <xsl:text>topicNotices</xsl:text>
    </xsl:template>
    <xsl:template match="*[contains(@class,' bookmap/frontmatter ')]/* |
                         *[contains(@class,' bookmap/booklists ')]/*" mode="determineTopicType" priority="10">
      <!-- Catch topics in front matter that do not have another match.
           Changing priorities for the default rule or (e.g) preface can break customizations;
           the high priority + variable fallback will support old and new without breaking customizations. --> 
      <xsl:variable name="fallback" as="xs:string"><xsl:next-match/></xsl:variable>
      <xsl:value-of select="if ($fallback = 'topicSimple') then 'topicFrontMatter' else $fallback"/>
    </xsl:template>
  
    <xsl:function name="opentopic-func:determineTopicType" as="xs:string">
      <xsl:variable name="topicType" as="xs:string">
        <xsl:call-template name="determineTopicType"/>
      </xsl:variable>
      <xsl:sequence select="$topicType"/>
    </xsl:function>

    <xsl:function name="dita-ot:notExcludedByDraftElement" as="xs:boolean">
      <xsl:param name="ctx" as="element()"/>
      <xsl:choose>
        <xsl:when test="$publishRequiredCleanup='yes' or $DRAFT='yes'">
            <xsl:sequence select="true()"/>
        </xsl:when>
        <xsl:when test="$ctx/ancestor::*[contains(@class,' topic/draft-comment ') or 
                                         contains(@class,' topic/required-cleanup ')]">
            <xsl:sequence select="false()"/>
        </xsl:when>
        <xsl:otherwise>
            <xsl:sequence select="true()"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:function>

</xsl:stylesheet>
