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

    <xsl:template match="*[contains(@class, ' topic/topic ')]">
      <xsl:apply-templates select="." mode="processTopic"/>
    </xsl:template>
      
    <xsl:template match="*" mode="processTopic">
      <fo:block xsl:use-attribute-sets="topic">
        <xsl:apply-templates select="." mode="commonTopicProcessing"/>
      </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/topic ')]/*[contains(@class,' topic/title ')]">
        <xsl:variable name="topicType" as="xs:string">
            <xsl:call-template name="determineTopicType"/>
        </xsl:variable>
        <xsl:choose>
            <!--  Disable chapter title processing when mini TOC is created -->
            <xsl:when test="(topicType = 'topicChapter') or (topicType = 'topicAppendix')" />
            <!--   Normal processing         -->
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="processTopicTitle"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="processTopicTitle">
        <xsl:variable name="level" as="xs:integer">
          <xsl:apply-templates select="." mode="get-topic-level"/>
        </xsl:variable>
        <xsl:variable name="attrSet1">
            <xsl:apply-templates select="." mode="createTopicAttrsName">
                <xsl:with-param name="theCounter" select="$level"/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:variable name="attrSet2" select="concat($attrSet1, '__content')"/>
        <fo:block>
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="$attrSet1"/>
                <xsl:with-param name="path" select="'../../cfg/fo/attrs/commons-attr.xsl'"/>
            </xsl:call-template>
            <fo:block>
                <xsl:call-template name="processAttrSetReflection">
                    <xsl:with-param name="attrSet" select="$attrSet2"/>
                    <xsl:with-param name="path" select="'../../cfg/fo/attrs/commons-attr.xsl'"/>
                </xsl:call-template>
                <xsl:if test="$level = 1">
                    <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
                </xsl:if>
                <xsl:if test="$level = 2">
                    <xsl:apply-templates select="." mode="insertTopicHeaderMarker">
                      <xsl:with-param name="marker-class-name" as="xs:string">current-h2</xsl:with-param>
                    </xsl:apply-templates>
                </xsl:if>
                <fo:wrapper id="{parent::node()/@id}"/>
                <fo:wrapper>
                    <xsl:attribute name="id">
                        <xsl:call-template name="generate-toc-id">
                            <xsl:with-param name="element" select=".."/>
                        </xsl:call-template>
                    </xsl:attribute>
                </fo:wrapper>
                <xsl:apply-templates select="." mode="customTopicAnchor"/>
                <xsl:call-template name="pullPrologIndexTerms"/>
                <xsl:apply-templates select="preceding-sibling::*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                <xsl:apply-templates select="." mode="getTitle"/>
            </fo:block>
        </fo:block>
    </xsl:template>

  <xsl:template match="*" mode="get-topic-level" as="xs:integer">
    <xsl:variable name="topicref" 
      select="key('map-id', ancestor-or-self::*[contains(@class,' topic/topic ')][1]/@id)[1]"
      as="element()?"
    />
    <xsl:sequence select="count(ancestor-or-self::*[contains(@class,' topic/topic ')]) -
                          count($topicref/ancestor-or-self::*[(contains(@class,' bookmap/part ') and
                                                               ((exists(@navtitle) or
                                                                 *[contains(@class,' map/topicmeta ')]/*[contains(@class,' topic/navtitle ')]) or
                                                                (exists(@href) and
                                                                 (empty(@format) or @format eq 'dita') and
                                                                 (empty(@scope) or @scope eq 'local')))) or
                                                              (contains(@class,' bookmap/appendices ') and
                                                               exists(@href) and
                                                               (empty(@format) or @format eq 'dita') and
                                                               (empty(@scope) or @scope eq 'local'))])"/>
  </xsl:template>

    <xsl:template match="*" mode="createTopicAttrsName">
      <xsl:param name="theCounter" as="xs:integer"/>
      <xsl:param name="theName" select="''" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="$theCounter > 0">
                <xsl:apply-templates select="." mode="createTopicAttrsName">
                    <xsl:with-param name="theCounter" select="$theCounter - 1"/>
                    <xsl:with-param name="theName" select="concat($theName, 'topic.')"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($theName, 'title')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Hook that allows adding anchors to titled non topic elements. -->
    <xsl:template match="*[contains(@class,' topic/title ')]" mode="customTitleAnchor"/>

    <xsl:template match="*[contains(@class,' topic/section ')]/*[contains(@class,' topic/title ')]">
        <fo:block xsl:use-attribute-sets="section.title">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="customTitleAnchor"/>
            <xsl:apply-templates select="." mode="getTitle"/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/example ')]/*[contains(@class,' topic/title ')]">
        <fo:block xsl:use-attribute-sets="example.title">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="customTitleAnchor"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/fig ')]/*[contains(@class,' topic/title ')]">
        <fo:block xsl:use-attribute-sets="fig.title">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="customTitleAnchor"/>
            <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="'Figure.title'"/>
                <xsl:with-param name="params">
                    <number>
                        <xsl:apply-templates select="." mode="fig.title-number"/>
                    </number>
                    <title>
                        <xsl:apply-templates/>
                    </title>
                </xsl:with-param>
            </xsl:call-template>
        </fo:block>
    </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/fig ')]/*[contains(@class,' topic/title ')]" mode="fig.title-number">
    <xsl:value-of select="count(key('enumerableByClass', 'topic/fig')[. &lt;&lt; current()][dita-ot:notExcludedByDraftElement(.)])"/>
  </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/tm ')]">
      <xsl:variable name="generate-symbol" as="xs:boolean">
        <xsl:apply-templates select="." mode="tm-scope"/>
      </xsl:variable>
        <fo:inline xsl:use-attribute-sets="tm">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
            <xsl:choose>
              <xsl:when test="not($generate-symbol)"/>
                <xsl:when test="@tmtype='service'">
                  <fo:inline xsl:use-attribute-sets="tm__content__service">&#8480;</fo:inline>
                </xsl:when>
                <xsl:when test="@tmtype='tm'">
                    <fo:inline xsl:use-attribute-sets="tm__content">&#8482;</fo:inline>
                </xsl:when>
                <xsl:when test="@tmtype='reg'">
                    <fo:inline xsl:use-attribute-sets="tm__content">&#174;</fo:inline>
                </xsl:when>
            </xsl:choose>
        </fo:inline>
    </xsl:template>

  <xsl:template match="node() | @*" mode="tm-scope" as="xs:boolean" priority="-10">
    <xsl:sequence select="true()"/>
  </xsl:template>  
  
  <xsl:template match="*[contains(@class,' topic/term ')]" name="topic.term">
    <xsl:param name="keys" select="@keyref" as="attribute()?"/>
    <xsl:param name="contents" as="node()*">
      <!-- Current node can be preprocessed and may not be part of source document, check for root() to ensure key() is resolvable -->
      <xsl:variable name="target" select="if (exists(root()) and @href) then key('id', substring(@href, 2))[1] else ()" as="element()?"/>
      <xsl:choose>
        <xsl:when test="not(normalize-space(.)) and $keys and $target/self::*[contains(@class,' topic/topic ')]">
          <xsl:apply-templates select="$target/*[contains(@class, ' topic/title ')]/node()"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:variable name="topicref" select="key('map-id', substring(@href, 2))[1]" as="element()?"/>
    <xsl:choose>
      <xsl:when test="$keys and @href and not($topicref/ancestor-or-self::*[@linking][1]/@linking = ('none', 'sourceonly'))">
        <fo:basic-link xsl:use-attribute-sets="xref term">
          <xsl:call-template name="commonattributes"/>
          <xsl:call-template name="buildBasicLinkDestination"/>
          <xsl:copy-of select="$contents"/>
        </fo:basic-link>
      </xsl:when>
      <xsl:otherwise>
        <fo:inline xsl:use-attribute-sets="term">
          <xsl:call-template name="commonattributes"/>
          <xsl:copy-of select="$contents"/>
        </fo:inline>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/author ')]">
<!--
        <fo:block xsl:use-attribute-sets="author">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/source ')]">
<!--
        <fo:block xsl:use-attribute-sets="source">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>


    <xsl:template match="*[contains(@class, ' topic/publisher ')]">
<!--
        <fo:block xsl:use-attribute-sets="publisher">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/copyright ')]">
<!--
        <fo:block xsl:use-attribute-sets="copyright">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/copyryear ')]">
<!--
        <fo:block xsl:use-attribute-sets="copyryear">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/copyrholder ')]">
<!--
        <fo:block xsl:use-attribute-sets="copyrholder">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/critdates ')]">
<!--
        <fo:block xsl:use-attribute-sets="critdates">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/created ')]">
<!--
        <fo:block xsl:use-attribute-sets="created">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/revised ')]">
<!--
        <fo:block xsl:use-attribute-sets="revised">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/permissions ')]">
<!--
        <fo:block xsl:use-attribute-sets="permissions">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/category ')]">
<!--
        <fo:block xsl:use-attribute-sets="category">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/audience ')]">
<!--
        <fo:block xsl:use-attribute-sets="audience">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/keywords ')]">
<!--
        <fo:block xsl:use-attribute-sets="keywords">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/prodinfo ')]">
<!--
        <fo:block xsl:use-attribute-sets="prodinfo">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/prodname ')]">
<!--
        <fo:block xsl:use-attribute-sets="prodname">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/vrmlist ')]">
<!--
        <fo:block xsl:use-attribute-sets="vrmlist">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/vrm ')]">
<!--
        <fo:block xsl:use-attribute-sets="vrm">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/brand ')]">
<!--
        <fo:block xsl:use-attribute-sets="brand">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/series ')]">
<!--
        <fo:block xsl:use-attribute-sets="series">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/platform ')]">
<!--
        <fo:block xsl:use-attribute-sets="platform">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/prognum ')]">
<!--
        <fo:block xsl:use-attribute-sets="prognum">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/featnum ')]">
<!--
        <fo:block xsl:use-attribute-sets="featnum">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/component ')]">
<!--
        <fo:block xsl:use-attribute-sets="component">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/othermeta ')]">
<!--
        <fo:block xsl:use-attribute-sets="othermeta">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/resourceid ')]">
<!--
        <fo:block xsl:use-attribute-sets="resourceid">
            <xsl:apply-templates/>
        </fo:block>
-->
    </xsl:template>

    <!-- Gets navigation title of current topic, used for bookmarks/TOC -->
    <xsl:template name="getNavTitle">
        <xsl:variable name="topicref" select="key('map-id', @id)[1]" as="element()?"/>
        <xsl:choose>
            <xsl:when test="$topicref/@locktitle='yes' and
                            $topicref/*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
               <xsl:apply-templates select="$topicref/*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]/node()"/>
            </xsl:when>
            <xsl:when test="$topicref/@locktitle='yes' and
                            $topicref/@navtitle">
                <xsl:value-of select="$topicref/@navtitle"/>
            </xsl:when>
            <xsl:when test="*[contains(@class,' topic/titlealts ')]/*[contains(@class,' topic/navtitle ')]">
                <xsl:apply-templates select="*[contains(@class,' topic/titlealts ')]/*[contains(@class,' topic/navtitle ')]/node()"/> 
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="*[contains(@class,' topic/title ')]" mode="getTitle"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="getTitle">
        <xsl:choose>
<!--             add keycol here once implemented-->
            <xsl:when test="@spectitle">
                <xsl:value-of select="@spectitle"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/titlealts ')]">
      <xsl:if test="$DRAFT='yes'">
        <xsl:if test="*">
          <fo:block xsl:use-attribute-sets="titlealts">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
          </fo:block>
        </xsl:if>
      </xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/navtitle ')]">
        <fo:block xsl:use-attribute-sets="navtitle">
            <xsl:call-template name="commonattributes"/>
            <fo:inline xsl:use-attribute-sets="navtitle__label">
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Navigation title'"/>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
            </fo:inline>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <!-- Map uses map/searchtitle, topic uses topic/searchtitle. This will likely be changed
         to a single value in DITA 2.0, but for now, recognize both. -->
    <xsl:template match="*[contains(@class,' topic/titlealts ')]/*[contains(@class,' topic/searchtitle ')] |
                         *[contains(@class,' topic/titlealts ')]/*[contains(@class,' map/searchtitle ')]">
        <fo:block xsl:use-attribute-sets="searchtitle">
            <xsl:call-template name="commonattributes"/>
            <fo:inline xsl:use-attribute-sets="searchtitle__label">
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Search title'"/>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
            </fo:inline>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/abstract ')]">
        <fo:block xsl:use-attribute-sets="abstract">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>
    
    <xsl:function name="dita-ot:formatShortdescAsBlock" as="xs:boolean">
        <xsl:param name="ctx" as="element()"/>
        <xsl:choose>
            <xsl:when test="not($ctx/parent::*[contains(@class,' topic/abstract ')])">
                <xsl:sequence select="true()"/>
            </xsl:when>
            <xsl:when test="$ctx/preceding-sibling::*[contains(@class,' topic/p ') or contains(@class,' topic/dl ') or
                contains(@class,' topic/fig ') or contains(@class,' topic/lines ') or
                contains(@class,' topic/lq ') or contains(@class,' topic/note ') or
                contains(@class,' topic/ol ') or contains(@class,' topic/pre ') or
                contains(@class,' topic/simpletable ') or contains(@class,' topic/sl ') or
                contains(@class,' topic/table ') or contains(@class,' topic/ul ') or
                contains(@class,' topic/div ')]">
                <xsl:sequence select="true()"/>
            </xsl:when>
            <xsl:when test="$ctx/following-sibling::*[contains(@class,' topic/p ') or contains(@class,' topic/dl ') or
                contains(@class,' topic/fig ') or contains(@class,' topic/lines ') or
                contains(@class,' topic/lq ') or contains(@class,' topic/note ') or
                contains(@class,' topic/ol ') or contains(@class,' topic/pre ') or
                contains(@class,' topic/simpletable ') or contains(@class,' topic/sl ') or
                contains(@class,' topic/table ') or contains(@class,' topic/ul ') or
                contains(@class,' topic/div ')]">
                <xsl:sequence select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- For SF Bug 2879171: modify so that shortdesc is inline when inside
         abstract with only other text or inline markup. -->
    <xsl:template match="*[contains(@class,' topic/shortdesc ')]">
        <xsl:variable name="format-as-block" as="xs:boolean" select="dita-ot:formatShortdescAsBlock(.)"/>
        <xsl:choose>
            <xsl:when test="$format-as-block">
                <xsl:apply-templates select="." mode="format-shortdesc-as-block"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="format-shortdesc-as-inline"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="format-shortdesc-as-block">
        <!--compare the length of shortdesc with the got max chars-->
        <fo:block xsl:use-attribute-sets="topic__shortdesc">
            <xsl:call-template name="commonattributes"/>
            <!-- If the shortdesc is sufficiently short, add keep-with-next. -->
            <xsl:if test="string-length(.) lt $maxCharsInShortDesc">
                <!-- Low-strength keep to avoid conflict with keeps on titles. -->
                <xsl:attribute name="keep-with-next.within-page">5</xsl:attribute>
            </xsl:if>
            <xsl:if test="parent::*[contains(@class,' topic/abstract ')]">
                <xsl:attribute name="start-indent">from-parent(start-indent)</xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*" mode="format-shortdesc-as-inline">
        <fo:inline xsl:use-attribute-sets="shortdesc">
            <xsl:call-template name="commonattributes"/>
            <xsl:if test="preceding-sibling::* | preceding-sibling::text()">
                <xsl:text> </xsl:text>
            </xsl:if>
            <xsl:apply-templates/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' map/shortdesc ')]">
        <xsl:apply-templates select="." mode="format-shortdesc-as-block"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/topic ')]/*[contains(@class,' topic/shortdesc ')]" priority="1">
        <xsl:variable name="topicType" as="xs:string">
            <xsl:call-template name="determineTopicType"/>
        </xsl:variable>
        <xsl:choose>
            <!--  Disable chapter summary processing when mini TOC is created -->
            <xsl:when test="$topicType = ('topicChapter', 'topicAppendix') and
                            $chapterLayout != 'BASIC'"/>
            <!--   Normal processing         -->
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="format-shortdesc-as-block"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="getMaxCharsForShortdescKeep" as="xs:integer">
    <!-- These values specify the length of a short description that will
        render with keep-with-next set, which should be (approximately) the
        character count in three lines of rendered shortdesc text. If you customize the
        default font, page margins, or shortdesc attribute sets, you may need
        to change these values. -->
        <xsl:choose>
            <xsl:when test="$locale = 'en_US' or $locale = 'fr_FR'">
              <xsl:sequence select="360"/>
            </xsl:when>
            <xsl:when test="$locale = 'ja_JP'">
              <xsl:sequence select="141"/>
            </xsl:when>
            <xsl:when test="$locale = 'zh_CN'">
              <xsl:sequence select="141"/>
            </xsl:when>
            <!-- Other languages require a template override to generate
            keep-with-next
            on shortdesc. Data was not available at the time this code released.
            -->
            <xsl:otherwise>
              <xsl:sequence select="0"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- this is the fallthrough body for nested topics -->
    <xsl:template match="*[contains(@class,' topic/body ')]">
        <xsl:variable name="level" as="xs:integer">
          <xsl:apply-templates select="." mode="get-topic-level"/>
        </xsl:variable>
        <xsl:choose>
                <xsl:when test="not(node())"/>
                <xsl:when test="$level = 1">
                    <fo:block xsl:use-attribute-sets="body__toplevel">
                        <xsl:apply-templates/>
                    </fo:block>
                </xsl:when>
                <xsl:when test="$level = 2">
                    <fo:block xsl:use-attribute-sets="body__secondLevel">
                        <xsl:apply-templates/>
                    </fo:block>
                </xsl:when>
                <xsl:otherwise>
                    <fo:block xsl:use-attribute-sets="body">
                        <xsl:apply-templates/>
                    </fo:block>
                </xsl:otherwise>
            </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/bodydiv ')]">
        <fo:block>
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

  <xsl:template match="*[contains(@class,' topic/section ')]
                        [@spectitle != '' and not(*[contains(@class, ' topic/title ')])]"
                mode="dita2xslfo:section-heading"
                priority="10">
    <fo:block xsl:use-attribute-sets="section.title">
      <xsl:call-template name="commonattributes"/>
      <xsl:variable name="spectitleValue" as="xs:string" select="string(@spectitle)"/>
      <xsl:variable name="resolvedVariable">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="$spectitleValue"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:sequence select="if (not(normalize-space($resolvedVariable)))
                            then $spectitleValue
                            else $resolvedVariable" />
    </fo:block>

  </xsl:template>
    <xsl:template match="*[contains(@class,' topic/section ')]" mode="dita2xslfo:section-heading">
      <!-- Specialized section elements may override this rule to add
           default headings for a section. By default, titles are processed
           where they exist within the section, so overrides may need to
           check for the existence of a title first. -->
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/section ')]">
        <fo:block xsl:use-attribute-sets="section">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="dita2xslfo:section-heading"/>
            <xsl:apply-templates select="*[contains(@class,' topic/title ')]"/>
            <fo:block xsl:use-attribute-sets="section__content">
                <xsl:apply-templates select="node() except (*[contains(@class,' topic/title ')])"/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/sectiondiv ')]">
        <fo:block>
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/example ')]">
        <fo:block xsl:use-attribute-sets="example">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="*[contains(@class,' topic/title ')]"/>
            <fo:block xsl:use-attribute-sets="example__content">
                <xsl:apply-templates select="node() except (*[contains(@class,' topic/title ')])"/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/desc ')]">
        <fo:inline xsl:use-attribute-sets="desc">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/prolog ')]"/>
<!--
        <fo:block xsl:use-attribute-sets="prolog">
            <xsl:apply-templates/>
        </fo:block>
-->
        <!--xsl:copy-of select="node()"/-->
        <!--xsl:apply-templates select="descendant::opentopic-index:index.entry[not(parent::opentopic-index:index.entry)]"/-->
    <!--/xsl:template-->

    <xsl:template name="pullPrologIndexTerms">
      <!-- index terms and ranges from topic -->
        <xsl:apply-templates select="ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/*[contains(@class, ' topic/prolog ')]
            //opentopic-index:index.entry[not(parent::opentopic-index:index.entry) and not(@end-range = 'true')]"/>
      <!-- index ranges from map -->
      <xsl:variable name="topicref" select="key('map-id', @id)[1]" as="element()?"/>
      <xsl:apply-templates select="$topicref/
                                     *[contains(@class, ' map/topicmeta ')]/
                                       *[contains(@class, ' topic/keywords ')]/
                                         descendant::opentopic-index:index.entry[@start-range = 'true']"/>
    </xsl:template>
  
    <xsl:template name="pullPrologIndexTerms.end-range">
      <!-- index ranges from topic -->
        <xsl:apply-templates select="ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/
                                       *[contains(@class, ' topic/prolog ')]/
                                         descendant::opentopic-index:index.entry[not(parent::opentopic-index:index.entry) and
                                                                                 @end-range = 'true']"/>
      <!-- index ranges from map -->
      <xsl:variable name="topicref" select="key('map-id', @id)[1]" as="element()?"/>
      <xsl:apply-templates select="$topicref/
                                     *[contains(@class, ' map/topicmeta ')]/
                                       *[contains(@class, ' topic/keywords ')]/
                                         descendant::opentopic-index:index.entry[@end-range = 'true']"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/metadata ')]">
<!--
        <fo:block xsl:use-attribute-sets="metadata">
            <xsl:apply-templates/>
        </fo:block>
-->
        <xsl:apply-templates select="descendant::opentopic-index:index.entry[not(parent::opentopic-index:index.entry)]"/>
    </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/div ')]">
    <fo:block xsl:use-attribute-sets="div">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:block>
  </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/p ')]">
        <fo:block xsl:use-attribute-sets="p">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*" mode="placeNoteContent">
        <fo:block xsl:use-attribute-sets="note">
            <xsl:call-template name="commonattributes"/>
            <fo:inline xsl:use-attribute-sets="note__label">
                <xsl:choose>
                    <xsl:when test="@type='note' or not(@type)">
                        <fo:inline xsl:use-attribute-sets="note__label__note">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Note'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='notice'">
                        <fo:inline xsl:use-attribute-sets="note__label__notice">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Notice'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='tip'">
                        <fo:inline xsl:use-attribute-sets="note__label__tip">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Tip'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='fastpath'">
                        <fo:inline xsl:use-attribute-sets="note__label__fastpath">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Fastpath'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='restriction'">
                        <fo:inline xsl:use-attribute-sets="note__label__restriction">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Restriction'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='important'">
                        <fo:inline xsl:use-attribute-sets="note__label__important">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Important'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='remember'">
                        <fo:inline xsl:use-attribute-sets="note__label__remember">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Remember'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='attention'">
                        <fo:inline xsl:use-attribute-sets="note__label__attention">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Attention'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='caution'">
                        <fo:inline xsl:use-attribute-sets="note__label__caution">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Caution'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='danger'">
                        <fo:inline xsl:use-attribute-sets="note__label__danger">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Danger'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='warning'">
                        <fo:inline xsl:use-attribute-sets="note__label__danger">
                            <xsl:call-template name="getVariable">
                                <xsl:with-param name="id" select="'Warning'"/>
                            </xsl:call-template>
                        </fo:inline>
                    </xsl:when>
                    <xsl:when test="@type='trouble'">
                      <fo:inline xsl:use-attribute-sets="note__label__trouble">
                        <xsl:call-template name="getVariable">
                          <xsl:with-param name="id" select="'Trouble'"/>
                        </xsl:call-template>
                      </fo:inline>
                    </xsl:when>                  
                    <xsl:when test="@type='other'">
                        <fo:inline xsl:use-attribute-sets="note__label__other">
                            <xsl:choose>
                                <xsl:when test="@othertype">
                                    <xsl:value-of select="@othertype"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>[</xsl:text>
                                    <xsl:value-of select="@type"/>
                                    <xsl:text>]</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </fo:inline>
                    </xsl:when>
                </xsl:choose>
                <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'#note-separator'"/>
                </xsl:call-template>
            </fo:inline>
            <xsl:text>  </xsl:text>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/note ')]" mode="setNoteImagePath">
      <xsl:variable name="noteType" as="xs:string">
          <xsl:choose>
              <xsl:when test="@type">
                  <xsl:value-of select="@type"/>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:value-of select="'note'"/>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:variable>
      <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="concat($noteType, ' Note Image Path')"/>
      </xsl:call-template>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/note ')]">
        <xsl:variable name="noteImagePath">
            <xsl:apply-templates select="." mode="setNoteImagePath"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="not($noteImagePath = '')">
                <fo:table xsl:use-attribute-sets="note__table">
                    <fo:table-column xsl:use-attribute-sets="note__image__column"/>
                    <fo:table-column xsl:use-attribute-sets="note__text__column"/>
                    <fo:table-body>
                        <fo:table-row>
                                <fo:table-cell xsl:use-attribute-sets="note__image__entry">
                                    <fo:block>
                                        <fo:external-graphic src="url('{concat($artworkPrefix, $noteImagePath)}')" 
                                                             content-height="2em" padding-right="3pt"
                                                             vertical-align="middle"
                                                             baseline-shift="baseline"/>
                                    </fo:block>
                                </fo:table-cell>
                                <fo:table-cell xsl:use-attribute-sets="note__text__entry">
                                    <xsl:apply-templates select="." mode="placeNoteContent"/>
                                </fo:table-cell>
                        </fo:table-row>
                    </fo:table-body>
                </fo:table>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="placeNoteContent"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/lq ')]">
        <fo:block xsl:use-attribute-sets="lq">
            <xsl:call-template name="commonattributes"/>
            <xsl:choose>
                <xsl:when test="@href or @reftitle">
                    <xsl:call-template name="processAttrSetReflection">
                        <xsl:with-param name="attrSet" select="'lq'"/>
                        <xsl:with-param name="path" select="'../../cfg/fo/attrs/commons-attr.xsl'"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="processAttrSetReflection">
                        <xsl:with-param name="attrSet" select="'lq_simple'"/>
                        <xsl:with-param name="path" select="'../../cfg/fo/attrs/commons-attr.xsl'"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:apply-templates/>
        </fo:block>
        <xsl:choose>
            <xsl:when test="@href">
                <fo:block xsl:use-attribute-sets="lq_link">
                    <fo:basic-link>
                        <xsl:call-template name="buildBasicLinkDestination">
                            <xsl:with-param name="scope" select="@scope"/>
                            <xsl:with-param name="format" select="@format"/>
                            <xsl:with-param name="href" select="@href"/>
                        </xsl:call-template>

                        <xsl:choose>
                            <xsl:when test="@reftitle">
                                <xsl:value-of select="@reftitle"/>
                            </xsl:when>
                            <xsl:when test="not(@type = 'external' or @format = 'html')">
                                <xsl:apply-templates select="." mode="insertReferenceTitle">
                                    <xsl:with-param name="href" select="@href"/>
                                    <xsl:with-param name="titlePrefix" select="''"/>
                                </xsl:apply-templates>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="@href"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </fo:basic-link>
                </fo:block>
            </xsl:when>
            <xsl:when test="@reftitle">
                <fo:block xsl:use-attribute-sets="lq_title">
                    <xsl:value-of select="@reftitle"/>
                </fo:block>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/q ')]">
        <fo:inline xsl:use-attribute-sets="q">
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="'#quote-start'"/>
            </xsl:call-template>
            <xsl:apply-templates/>
            <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="'#quote-end'"/>
            </xsl:call-template>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/fig ')]">
        <fo:block xsl:use-attribute-sets="fig">
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="setFrame"/>
            <xsl:call-template name="setExpanse"/>
            <xsl:call-template name="setScale"/>
            <xsl:if test="not(@id)">
              <xsl:attribute name="id">
                <xsl:call-template name="get-id"/>
              </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="*[not(contains(@class,' topic/title '))]"/>
            <xsl:apply-templates select="*[contains(@class,' topic/title ')]"/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/figgroup ')]">
        <fo:block xsl:use-attribute-sets="figgroup">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/pre ')]">
        <xsl:call-template name="setSpecTitle"/>
        <fo:block xsl:use-attribute-sets="pre">
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="setFrame"/>
            <xsl:call-template name="setScale"/>
            <xsl:call-template name="setExpanse"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template name="setSpecTitle">
        <xsl:if test="@spectitle">
            <fo:block xsl:use-attribute-sets="__spectitle">
                <xsl:value-of select="@spectitle"/>
            </fo:block>
        </xsl:if>
    </xsl:template>

    <xsl:template name="setScale">
        <xsl:if test="@scale">
            <!-- For applications that do not yet take percentages. need to divide by 10 and use "pt" -->
            <xsl:attribute name="font-size">
                <xsl:value-of select="concat(@scale, '%')"/>
            </xsl:attribute>
        </xsl:if>
    </xsl:template>

    <!-- Process the frame attribute -->
    <!-- frame styles (setframe) must be called within a block that defines the content being framed -->
    <xsl:template name="setFrame" as="attribute()*">
      <xsl:variable name="container" as="element()*">
        <xsl:choose>
         <xsl:when test="@frame = 'top'">
           <element xsl:use-attribute-sets="__border__top"/>
         </xsl:when>
         <xsl:when test="@frame = 'bot'">
           <element xsl:use-attribute-sets="__border__bot"/>
         </xsl:when>
          <xsl:when test="@frame = 'topbot'">
            <element xsl:use-attribute-sets="__border__topbot"/>
          </xsl:when>
         <xsl:when test="@frame = 'sides'">
           <element xsl:use-attribute-sets="__border__sides"/>
         </xsl:when>
         <xsl:when test="@frame = 'all'">
           <element xsl:use-attribute-sets="__border__all"/>
         </xsl:when>
        </xsl:choose>
      </xsl:variable>
      <xsl:sequence select="$container/@*"/>
    </xsl:template>

    <xsl:template name="setExpanse" as="attribute()*">
      <xsl:variable name="container" as="element()*">
        <xsl:choose>
         <xsl:when test="@expanse = 'page'">
           <element xsl:use-attribute-sets="__expanse__page"/>
         </xsl:when>
         <xsl:when test="@expanse = 'column'">
           <element xsl:use-attribute-sets="__expanse__column"/>
         </xsl:when>
         <xsl:when test="@expanse = 'spread'">
           <element xsl:use-attribute-sets="__expanse__spread"/>
         </xsl:when>
         <xsl:when test="@expanse = 'column'">
           <element xsl:use-attribute-sets="__expanse__textline"/>
         </xsl:when>
        </xsl:choose>
      </xsl:variable>
      <xsl:sequence select="$container/@*"/>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/lines ')]">
        <xsl:call-template name="setSpecTitle"/>
        <fo:block xsl:use-attribute-sets="lines">
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="setFrame"/>
            <xsl:call-template name="setScale"/>
            <xsl:call-template name="setExpanse"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <!-- The text element has no default semantics or formatting -->
    <xsl:template match="*[contains(@class,' topic/text ')]">
        <fo:inline>
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:inline>
    </xsl:template>

  <xsl:template match="*" mode="inlineTextOptionalKeyref">
    <xsl:param name="copyAttributes" as="element()?"/>
    <xsl:param name="keys" select="@keyref" as="attribute()?"/>
    <xsl:param name="contents" as="node()*">
      <!-- Current node can be preprocessed and may not be part of source document, check for root() to ensure key() is resolvable -->
      <xsl:variable name="target" select="if (exists(root()) and @href) then key('id', substring(@href, 2))[1] else ()" as="element()?"/>
      <xsl:choose>
        <xsl:when test="not(normalize-space(.)) and $keys and $target/self::*[contains(@class,' topic/topic ')]">
          <xsl:apply-templates select="$target/*[contains(@class, ' topic/title ')]/node()"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:variable name="topicref" select="key('map-id', substring(@href, 2))[1]" as="element()?"/>
    <xsl:choose>
      <xsl:when test="$keys and @href and not($topicref/ancestor-or-self::*[@linking][1]/@linking = ('none', 'sourceonly'))">
        <fo:basic-link xsl:use-attribute-sets="xref">
          <xsl:sequence select="$copyAttributes/@*"/>
          <xsl:call-template name="commonattributes"/>
          <xsl:call-template name="buildBasicLinkDestination"/>
          <xsl:copy-of select="$contents"/>
        </fo:basic-link>
      </xsl:when>
      <xsl:otherwise>
        <fo:inline>
          <xsl:sequence select="$copyAttributes/@*"/>
          <xsl:call-template name="commonattributes"/>
          <xsl:copy-of select="$contents"/>
        </fo:inline>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <xsl:template match="*[contains(@class,' topic/keyword ')]" name="topic.keyword">
        <xsl:apply-templates select="." mode="inlineTextOptionalKeyref">
            <xsl:with-param name="copyAttributes" as="element()"><wrapper xsl:use-attribute-sets="keyword"/></xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/ph ')]">
        <xsl:apply-templates select="." mode="inlineTextOptionalKeyref">
            <xsl:with-param name="copyAttributes" as="element()"><wrapper xsl:use-attribute-sets="ph"/></xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/boolean ')]">
        <fo:inline xsl:use-attribute-sets="boolean">
            <xsl:call-template name="commonattributes"/>
            <xsl:value-of select="name()"/>
            <xsl:text>: </xsl:text>
            <xsl:value-of select="@state"/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/state ')]">
        <fo:inline xsl:use-attribute-sets="state">
            <xsl:call-template name="commonattributes"/>
            <xsl:value-of select="name()"/>
            <xsl:text>: </xsl:text>
            <xsl:value-of select="@name"/>
            <xsl:text>=</xsl:text>
            <xsl:value-of select="@value"/>
        </fo:inline>
    </xsl:template>

  <xsl:variable name="job" select="document(resolve-uri('.job.xml', $work.dir.url))" as="document-node()?"/>
  <xsl:key name="jobFile" match="file" use="@uri"/>

    <xsl:template match="*[contains(@class,' topic/image ')]" name="image">
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="outofline"/>
        <xsl:choose>
            <xsl:when test="empty(@href)"/>
            <xsl:when test="@placement = 'break'">
                    <fo:block xsl:use-attribute-sets="image__block">
                        <xsl:call-template name="commonattributes"/>
                        <xsl:apply-templates select="." mode="placeImage">
                            <xsl:with-param name="imageAlign" select="@align"/>
                          <xsl:with-param name="href">
                            <xsl:choose>
                              <xsl:when test="@scope = 'external' or opentopic-func:isAbsolute(@href)">
                                <xsl:value-of select="@href"/>
                              </xsl:when>
                              <xsl:when test="exists(key('jobFile', @href, $job))">
                                <xsl:value-of select="key('jobFile', @href, $job)/@src"/>
                              </xsl:when>
                              <xsl:otherwise>
                                <xsl:value-of select="concat($input.dir.url, @href)"/>
                              </xsl:otherwise>
                            </xsl:choose>
                          </xsl:with-param>
                            <xsl:with-param name="height" select="@height"/>
                            <xsl:with-param name="width" select="@width"/>
                        </xsl:apply-templates>
                    </fo:block>
                    <xsl:if test="$artLabel='yes'">
                      <fo:block>
                        <xsl:apply-templates select="." mode="image.artlabel"/>
                      </fo:block>
                    </xsl:if>
            </xsl:when>
            <xsl:otherwise>
                <fo:inline xsl:use-attribute-sets="image__inline">
                    <xsl:call-template name="commonattributes"/>
                    <xsl:apply-templates select="." mode="placeImage">
                        <xsl:with-param name="imageAlign" select="@align"/>
                      <xsl:with-param name="href">
                        <xsl:choose>
                          <xsl:when test="@scope = 'external' or opentopic-func:isAbsolute(@href)">
                            <xsl:value-of select="@href"/>
                          </xsl:when>
                          <xsl:when test="exists(key('jobFile', @href, $job))">
                            <xsl:value-of select="key('jobFile', @href, $job)/@src"/>
                          </xsl:when>
                          <xsl:otherwise>
                            <xsl:value-of select="concat($input.dir.url, @href)"/>
                          </xsl:otherwise>
                        </xsl:choose>
                      </xsl:with-param>
                        <xsl:with-param name="height" select="@height"/>
                        <xsl:with-param name="width" select="@width"/>
                    </xsl:apply-templates>
                </fo:inline>
                <xsl:if test="$artLabel='yes'">
                  <xsl:apply-templates select="." mode="image.artlabel"/>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="outofline"/>
    </xsl:template>

    <xsl:template match="*" mode="image.artlabel">
      <fo:inline xsl:use-attribute-sets="image.artlabel">
        <xsl:text> </xsl:text>
        <xsl:value-of select="@href"/>
        <xsl:text> </xsl:text>
      </fo:inline>
    </xsl:template>
  
  <!-- Test whether URI is absolute -->
  <xsl:function name="opentopic-func:isAbsolute" as="xs:boolean">
    <xsl:param name="uri" as="xs:anyURI"/>
    <xsl:sequence select="some $prefix in ('/', 'file:') satisfies starts-with($uri, $prefix) or
                          contains($uri, '://')"/>
  </xsl:function>

    <xsl:template match="*" mode="placeImage">
        <xsl:param name="imageAlign"/>
        <xsl:param name="href"/>
        <xsl:param name="height" as="xs:string?"/>
        <xsl:param name="width" as="xs:string?"/>
        <xsl:param name="scale" as="xs:string?">
            <xsl:choose>
                <xsl:when test="@scale"><xsl:value-of select="@scale"/></xsl:when>
                <xsl:when test="ancestor::*[@scale]"><xsl:value-of select="ancestor::*[@scale][1]/@scale"/></xsl:when>
            </xsl:choose>
        </xsl:param>
<!--Using align attribute set according to image @align attribute-->
        <xsl:call-template name="processAttrSetReflection">
                <xsl:with-param name="attrSet" select="concat('__align__', $imageAlign)"/>
                <xsl:with-param name="path" select="'../../cfg/fo/attrs/commons-attr.xsl'"/>
            </xsl:call-template>
        <fo:external-graphic src="url('{$href}')" xsl:use-attribute-sets="image">
            <!--Setting image height if defined-->
            <xsl:if test="$height">
                <xsl:attribute name="content-height">
                <!--The following test was commented out because most people found the behavior
                 surprising.  It used to force images with a number specified for the dimensions
                 *but no units* to act as a measure of pixels, *if* you were printing at 72 DPI.
                 Uncomment if you really want it. -->
                    <xsl:choose>
                      <!--xsl:when test="not(string(number($height)) = 'NaN')">
                        <xsl:value-of select="concat($height div 72,'in')"/>
                      </xsl:when-->
                      <xsl:when test="not(string(number($height)) = 'NaN')">
                        <xsl:value-of select="concat($height, 'px')"/>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:value-of select="$height"/>
                      </xsl:otherwise>
                    </xsl:choose>
                </xsl:attribute>
            </xsl:if>
            <!--Setting image width if defined-->
            <xsl:if test="$width">
                <xsl:attribute name="content-width">
                    <xsl:choose>
                      <!--xsl:when test="not(string(number($width)) = 'NaN')">
                        <xsl:value-of select="concat($width div 72,'in')"/>
                      </xsl:when-->
                      <xsl:when test="not(string(number($width)) = 'NaN')">
                        <xsl:value-of select="concat($width, 'px')"/>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:value-of select="$width"/>
                      </xsl:otherwise>
                    </xsl:choose>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="not($width) and not($height) and $scale">
                <xsl:attribute name="content-width">
                    <xsl:value-of select="concat($scale,'%')"/>
                </xsl:attribute>
            </xsl:if>
          <xsl:if test="@scalefit = 'yes' and not($width) and not($height) and not($scale)">            
            <xsl:attribute name="width">100%</xsl:attribute>
            <xsl:attribute name="height">100%</xsl:attribute>
            <xsl:attribute name="content-width">scale-to-fit</xsl:attribute>
            <xsl:attribute name="content-height">scale-to-fit</xsl:attribute>
            <xsl:attribute name="scaling">uniform</xsl:attribute>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="*[contains(@class,' topic/alt ')]">
              <xsl:apply-templates select="*[contains(@class,' topic/alt ')]" mode="graphicAlternateText"/>
            </xsl:when>
            <xsl:when test="@alt">
              <xsl:apply-templates select="@alt" mode="graphicAlternateText"/>
            </xsl:when>
          </xsl:choose>
          
          <xsl:apply-templates select="node() except (text(),
                                                      *[contains(@class, ' topic/alt ') or
                                                        contains(@class, ' topic/longdescref ')])"/>
        </fo:external-graphic>
    </xsl:template>

    <xsl:template match="*|@alt" mode="graphicAlternateText"/>

    <xsl:template match="*[contains(@class,' topic/alt ')]">
        <fo:block xsl:use-attribute-sets="alt">
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/object ')]">
        <fo:inline xsl:use-attribute-sets="object">
            <xsl:call-template name="commonattributes"/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/param ')]">
        <fo:inline xsl:use-attribute-sets="param">
            <xsl:call-template name="commonattributes"/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/foreign ')]"/>
    <xsl:template match="*[contains(@class,' topic/unknown ')]"/>

    <xsl:template match="*[contains(@class,' topic/draft-comment ')]">
        <xsl:if test="$publishRequiredCleanup = 'yes' or $DRAFT='yes'">
            <fo:block xsl:use-attribute-sets="draft-comment">
                <xsl:call-template name="commonattributes"/>
                <fo:block xsl:use-attribute-sets="draft-comment__label">
                    <xsl:text>Disposition: </xsl:text>
                    <xsl:value-of select="@disposition"/>
                    <xsl:text> / </xsl:text>
                    <xsl:text>Status: </xsl:text>
                    <xsl:value-of select="@status"/>
                </fo:block>
                <xsl:apply-templates/>
            </fo:block>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/required-cleanup ')]">
        <xsl:if test="$publishRequiredCleanup = 'yes' or $DRAFT='yes'">
            <fo:inline xsl:use-attribute-sets="required-cleanup">
                <xsl:call-template name="commonattributes"/>
                <fo:inline xsl:use-attribute-sets="required-cleanup__label">
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Required-Cleanup'"/>
                    </xsl:call-template>
                    <xsl:if test="string(@remap)">
                        <xsl:text>(</xsl:text>
                        <xsl:value-of select="@remap"/>
                        <xsl:text>)</xsl:text>
                    </xsl:if>
                    <xsl:text>: </xsl:text>
                </fo:inline>
                <xsl:apply-templates/>
            </fo:inline>
        </xsl:if>
    </xsl:template>

    <xsl:function name="dita-ot:getFootnoteInternalID" as="xs:string">
      <xsl:param name="ctx" as="element()"/>
      <xsl:sequence select="concat('fn',generate-id($ctx))"/>
    </xsl:function>

    <xsl:template match="*[contains(@class,' topic/fn ')]">
      <xsl:variable name="id" select="dita-ot:getFootnoteInternalID(.)" as="xs:string"/>
      <xsl:variable name="callout" as="xs:string">
        <xsl:apply-templates select="." mode="callout"/>
      </xsl:variable>
        <fo:footnote>
            <xsl:choose>
              <xsl:when test="not(@id)">
                <fo:inline xsl:use-attribute-sets="fn__callout">
                  <fo:basic-link internal-destination="{$id}">
                    <xsl:copy-of select="$callout"/>
                  </fo:basic-link>
                </fo:inline>
              </xsl:when>
              <xsl:otherwise>
                <!-- Footnote with id does not generate its own callout. -->
                <fo:inline/>
              </xsl:otherwise>
            </xsl:choose>

            <fo:footnote-body>
                <fo:list-block xsl:use-attribute-sets="fn__body">
                    <fo:list-item>
                        <fo:list-item-label end-indent="label-end()">
                            <fo:block text-align="right" id="{$id}">
                                <fo:inline xsl:use-attribute-sets="fn__callout">
                                  <xsl:copy-of select="$callout"/>
                                </fo:inline>
                            </fo:block>
                        </fo:list-item-label>
                        <fo:list-item-body start-indent="body-start()" text-align="start">
                            <fo:block>
                                <xsl:apply-templates/>
                            </fo:block>
                        </fo:list-item-body>
                    </fo:list-item>
                </fo:list-block>
            </fo:footnote-body>
        </fo:footnote>
    </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/fn ')]" mode="callout">
    <xsl:choose>
      <xsl:when test="@callout">
        <xsl:value-of select="@callout"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="count(key('enumerableByClass', 'topic/fn')[. &lt;&lt; current()]) + 1"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <xsl:template match="*[contains(@class,' topic/indexterm ')]">
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/indextermref ')]">
        <fo:inline xsl:use-attribute-sets="indextermref">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/cite ')]">
        <xsl:apply-templates select="." mode="inlineTextOptionalKeyref">
            <xsl:with-param name="copyAttributes" as="element()"><wrapper xsl:use-attribute-sets="cite"/></xsl:with-param>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="@platform | @product | @audience | @otherprops | @importance | @rev | @status"/>

    <!-- Template to copy original IDs -->

    <xsl:template match="@id">
        <xsl:attribute name="id">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>
    
    <!-- Templates to reprocess reused content while dropping IDs from reuse context -->
    <xsl:template match="@id" mode="dropCopiedIds"/>
    <xsl:template match="*|@*|text()" mode="dropCopiedIds">
        <xsl:copy>
            <xsl:apply-templates select="@*|*|text()" mode="dropCopiedIds"/>
        </xsl:copy>
    </xsl:template>

    <!-- Process common attributes -->
    <xsl:template name="commonattributes">
      <xsl:apply-templates select="@id"/>
      <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')] |
                                   *[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="flag-attributes"/>
      <xsl:apply-templates select="@outputclass"/>
    </xsl:template>
  
  <xsl:template match="@outputclass"/>

    <!-- Get ID for an element, generate ID if not explicitly set. -->
    <xsl:template name="get-id">
      <xsl:param name="element" select="."/>
      <xsl:choose>
        <xsl:when test="$element/@id">
          <xsl:value-of select="$element/@id"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="generate-id($element)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <!-- Generate TOC ID -->
    <xsl:template name="generate-toc-id">
      <xsl:param name="element" select="."/>
      <xsl:value-of select="concat('_OPENTOPIC_TOC_PROCESSING_', generate-id($element))"/>
    </xsl:template>
  
    <xsl:template match="*[contains(@class, ' topic/data ')]"/>
    <xsl:template match="*[contains(@class, ' topic/data ')]" mode="insert-text"/>
    <xsl:template match="*[contains(@class, ' topic/data-about ')]"/>

</xsl:stylesheet>
