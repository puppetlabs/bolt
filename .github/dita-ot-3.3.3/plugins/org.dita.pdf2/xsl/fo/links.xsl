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
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:opentopic-mapmerge="http://www.idiominc.com/opentopic/mapmerge"
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="dita-ot opentopic-mapmerge opentopic-func related-links xs"
    version="2.0">
  
  <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>

  <xsl:param name="figurelink.style" select="'NUMTITLE'"/>
  <xsl:param name="tablelink.style" select="'NUMTITLE'"/>

  <!-- Deprecated since 2.3 -->
  <xsl:variable name="msgprefix">DOTX</xsl:variable>
  
    <xsl:key name="key_anchor" match="*[@id][not(contains(@class,' map/topicref '))]" use="@id"/>
<!--[not(contains(@class,' map/topicref '))]-->
    <xsl:template name="insertLinkShortDesc">
    <xsl:param name="destination"/>
    <xsl:param name="element"/>
    <xsl:param name="linkScope"/>
        <xsl:choose>
            <!-- User specified description (from map or topic): use that. -->
            <xsl:when test="*[contains(@class,' topic/desc ')] and
                            processing-instruction()[name()='ditaot'][.='usershortdesc']">
                <fo:block xsl:use-attribute-sets="link__shortdesc">
                    <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
                </fo:block>
            </xsl:when>
            <!-- External: do not attempt to retrieve. -->
            <xsl:when test="$linkScope='external'">
            </xsl:when>
            <!-- When the target has a short description and no local override, use the target -->
            <xsl:when test="$element/*[contains(@class, ' topic/shortdesc ')]">
                <xsl:variable name="generatedShortdesc" as="element()*">
                    <xsl:apply-templates select="$element/*[contains(@class, ' topic/shortdesc ')]"/>
                </xsl:variable>
                <fo:block xsl:use-attribute-sets="link__shortdesc">
                    <xsl:apply-templates select="$generatedShortdesc" mode="dropCopiedIds"/>
                </fo:block>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="insertLinkDesc">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Link description'"/>
            <xsl:with-param name="params">
                <desc>
                    <fo:inline>
                        <xsl:apply-templates select="*[contains(@class,' topic/desc ')]" mode="insert-description"/>
                    </fo:inline>
                </desc>
            </xsl:with-param>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/xref ') or contains(@class, ' topic/link ')]/*[contains(@class,' topic/desc ')]" priority="1"/>
    <xsl:template match="*[contains(@class,' topic/desc ')]" mode="insert-description">
        <xsl:apply-templates/>
    </xsl:template>


    <!-- The insertReferenceTitle template is called from <xref> and <link> and is
         used to build link contents (using full FO syntax, not just the text). -->
    <!-- Process any cross reference or link with author-specified text. 
         The specified text is used as the link text. -->
    <xsl:template match="*[processing-instruction()[name()='ditaot'][.='usertext']]" mode="insertReferenceTitle">
        <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))]|text()"/>
    </xsl:template>

    <!-- Process any cross reference or link with no content, or with content
         generated by the DITA-OT preprocess. The title will be retrieved from
         the target element, and combined with generated text such as Figure N. -->
    <xsl:template match="*" mode="insertReferenceTitle">
        <xsl:param name="href"/>
        <xsl:param name="titlePrefix"/>
        <xsl:param name="destination"/>
        <xsl:param name="element"/>

        <xsl:variable name="referenceContent">
            <xsl:choose>
                <xsl:when test="not($element) or ($destination = '')">
                    <xsl:text>#none#</xsl:text>
                </xsl:when>
                <xsl:when test="contains($element/@class,' topic/li ') and 
                                contains($element/parent::*/@class,' topic/ol ')">
                    <!-- SF Bug 1839827: This causes preprocessor text to be used for links to OL/LI -->
                    <xsl:text>#none#</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="$element" mode="retrieveReferenceTitle"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
                

        <xsl:if test="not($titlePrefix = '')">
            <xsl:call-template name="getVariable">
                <xsl:with-param name="id" select="$titlePrefix"/>
            </xsl:call-template>
        </xsl:if>

    <xsl:choose>
            <xsl:when test="not($element) or ($destination = '') or $referenceContent='#none#'">
                <xsl:choose>
                    <xsl:when test="*[not(contains(@class,' topic/desc '))] | text()">
                        <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))] | text()"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$href"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>

            <xsl:otherwise>
                <xsl:copy-of select="$referenceContent"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/fig ')][*[contains(@class, ' topic/title ')]]" mode="retrieveReferenceTitle">
      <xsl:choose>
        <xsl:when test="$figurelink.style='NUMBER'">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Figure Number'"/>
            <xsl:with-param name="params">
                <number>
                  <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="fig.title-number"/>
                </number>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="$figurelink.style='TITLE'">
          <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="insert-text"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Figure.title'"/>
            <xsl:with-param name="params">
                <number>
                  <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="fig.title-number"/>
                </number>
                <title>
                    <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="insert-text"/>
                </title>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/section ')][*[contains(@class, ' topic/title ')]]" mode="retrieveReferenceTitle">
        <xsl:variable name="title">
            <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="insert-text"/>
        </xsl:variable>
        <xsl:value-of select="normalize-space($title)"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/table ')][*[contains(@class, ' topic/title ')]]" mode="retrieveReferenceTitle">
      <xsl:choose>
        <xsl:when test="$tablelink.style='NUMBER'">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table Number'"/>
            <xsl:with-param name="params">
                <number>
                  <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="table.title-number"/>
                </number>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="$tablelink.style='TITLE'">
          <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="insert-text"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Table.title'"/>
            <xsl:with-param name="params">
                <number>
                  <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="table.title-number"/>
                </number>
                <title>
                    <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="insert-text"/>
                </title>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/li ')]" mode="retrieveReferenceTitle">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'List item'"/>
        </xsl:call-template>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/fn ')]" mode="retrieveReferenceTitle">
    <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Foot note'"/>
    </xsl:call-template>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/dlentry ')]" mode="retrieveReferenceTitle">
      <xsl:apply-templates select="*[contains(@class,' topic/dt ')][1]" mode="retrieveReferenceTitle"/>
    </xsl:template>
    <xsl:template match="*[contains(@class, ' topic/dt ')]" mode="retrieveReferenceTitle">
      <xsl:apply-templates select="." mode="text-only"/>
    </xsl:template>
  
    <xsl:template match="*[contains(@class, ' topic/title ')]" mode="retrieveReferenceTitle">
      <xsl:apply-templates select=".." mode="retrieveReferenceTitle"/>
    </xsl:template>

    <!-- Default rule: if element has a title, use that, otherwise return '#none#' -->
    <xsl:template match="*" mode="retrieveReferenceTitle" >
        <xsl:choose>
            <xsl:when test="*[contains(@class,' topic/title ')]">
                <xsl:value-of select="string(*[contains(@class, ' topic/title ')])"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>#none#</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/xref ')]" name="topic.xref">

    <xsl:variable name="destination" select="opentopic-func:getDestinationId(@href)"/>
    <xsl:variable name="element" select="key('key_anchor',$destination, $root)[1]" as="element()?"/>

    <xsl:variable name="referenceTitle" as="node()*">
      <xsl:apply-templates select="." mode="insertReferenceTitle">
        <xsl:with-param name="href" select="@href"/>
        <xsl:with-param name="titlePrefix" select="''"/>
        <xsl:with-param name="destination" select="$destination"/>
        <xsl:with-param name="element" select="$element"/>
      </xsl:apply-templates>
    </xsl:variable>

    <fo:basic-link xsl:use-attribute-sets="xref">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="buildBasicLinkDestination">
        <xsl:with-param name="scope" select="@scope"/>
        <xsl:with-param name="format" select="@format"/>
        <xsl:with-param name="href" select="@href"/>
      </xsl:call-template>

      <xsl:choose>
        <xsl:when test="not(@scope = 'external' or not(empty(@format) or  @format = 'dita')) and exists($referenceTitle)">
          <xsl:copy-of select="$referenceTitle"/>
        </xsl:when>
        <xsl:when test="not(@scope = 'external' or not(empty(@format) or  @format = 'dita'))">
          <xsl:call-template name="insertPageNumberCitation">
            <xsl:with-param name="isTitleEmpty" select="true()"/>
            <xsl:with-param name="destination" select="$destination"/>
            <xsl:with-param name="element" select="$element"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="*[not(contains(@class,' topic/desc '))] | text()">
              <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))] | text()" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="@href"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </fo:basic-link>

    <!--
        Disable because of the CQ#8102 bug
        <xsl:if test="*[contains(@class,' topic/desc ')]">
          <xsl:call-template name="insertLinkDesc"/>
        </xsl:if>
    -->

      <xsl:if test="not(@scope = 'external' or not(empty(@format) or  @format = 'dita')) and exists($referenceTitle) and not($element[contains(@class, ' topic/fn ')])">
            <!-- SourceForge bug 1880097: should not include page number when xref includes author specified text -->
            <xsl:if test="not(processing-instruction()[name()='ditaot'][.='usertext'])">
                <xsl:call-template name="insertPageNumberCitation">
                    <xsl:with-param name="destination" select="$destination"/>
                      <xsl:with-param name="element" select="$element"/>
                  </xsl:call-template>
            </xsl:if>
      </xsl:if>

    </xsl:template>

    <!-- xref to footnote makes a callout. -->
    <xsl:template match="*[contains(@class,' topic/xref ')][@type='fn']" priority="2">
        <xsl:variable name="href-fragment" select="substring-after(@href, '#')"/>
        <xsl:variable name="elemId" select="substring-after($href-fragment, '/')"/>
        <xsl:variable name="topicId" select="substring-before($href-fragment, '/')"/>
        <xsl:variable name="footnote-target" 
          select="(key('fnById', $elemId)[ancestor::*[contains(@class, ' topic/topic ')][1]/@id = $topicId])[1]" 
          as="element()?"
        />
        <xsl:apply-templates select="$footnote-target" mode="footnote-callout"/>
    </xsl:template>

  <xsl:template match="*[contains(@class,' topic/xref ')][empty(@href)]" priority="2">
    <fo:inline>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))] | text()" />
    </fo:inline>
  </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/fn ')]" mode="footnote-callout">
            <fo:inline xsl:use-attribute-sets="fn__callout">
              <fo:basic-link internal-destination="{dita-ot:getFootnoteInternalID(.)}">
                <xsl:apply-templates select="." mode="callout"/>
              </fo:basic-link>
            </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/related-links ')]">
        <xsl:if test="exists($includeRelatedLinkRoles)">
          <!--  
          <xsl:variable name="topicType">
                <xsl:for-each select="parent::*">
                    <xsl:call-template name="determineTopicType"/>
                </xsl:for-each>
            </xsl:variable>

            <xsl:variable name="collectedLinks">
                <xsl:apply-templates>
                    <xsl:with-param name="topicType" select="$topicType"/>
                </xsl:apply-templates>
            </xsl:variable>

            <xsl:variable name="linkTextContent" select="string($collectedLinks)"/>

            <xsl:if test="normalize-space($linkTextContent)!=''">
              <fo:block xsl:use-attribute-sets="related-links">

                <fo:block xsl:use-attribute-sets="related-links.title">
                  <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Related Links'"/>
                  </xsl:call-template>
                </fo:block>

                <fo:block xsl:use-attribute-sets="related-links__content">
                  <xsl:copy-of select="$collectedLinks"/>
                </fo:block>
              </fo:block>
            </xsl:if>

            -->
        <fo:block xsl:use-attribute-sets="related-links">
          <fo:block xsl:use-attribute-sets="related-links__content">
          <xsl:if test="$includeRelatedLinkRoles = ('child', 'descendant')">
            <xsl:call-template name="ul-child-links"/>
            <xsl:call-template name="ol-child-links"/>
          </xsl:if>
          <!--xsl:if test="$includeRelatedLinkRoles = ('next', 'previous', 'parent')">
            <xsl:call-template name="next-prev-parent-links"/>
          </xsl:if-->
          <xsl:variable name="unordered-links" as="element()*">
            <xsl:apply-templates select="." mode="related-links:group-unordered-links">
              <xsl:with-param name="nodes"
                              select="descendant::*[contains(@class, ' topic/link ')]
                                                   [not(related-links:omit-from-unordered-links(.))]
                                                   [generate-id(.) = generate-id(key('hideduplicates', related-links:hideduplicates(.))[1])]"/>
            </xsl:apply-templates>
          </xsl:variable>
          <xsl:apply-templates select="$unordered-links"/>
          <!--linklists - last but not least, create all the linklists and their links, with no sorting or re-ordering-->
          <xsl:apply-templates select="*[contains(@class, ' topic/linklist ')]"/>
          </fo:block>
        </fo:block>
      </xsl:if>
    </xsl:template>
  
  <xsl:template name="ul-child-links">
    <xsl:variable name="children"
                  select="descendant::*[contains(@class, ' topic/link ')]
                                       [@role = ('child', 'descendant')]
                                       [not(parent::*/@collection-type = 'sequence')]
                                       [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
    <xsl:if test="$children">
      <fo:list-block xsl:use-attribute-sets="related-links.ul">
        <xsl:for-each select="$children[generate-id(.) = generate-id(key('link', related-links:link(.))[1])]">
          <fo:list-item xsl:use-attribute-sets="related-links.ul.li">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="related-links.ul.li__label">
              <fo:block xsl:use-attribute-sets="related-links.ul.li__label__content">
                <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Unordered List bullet'"/>
                </xsl:call-template>
              </fo:block>
            </fo:list-item-label>
            <fo:list-item-body xsl:use-attribute-sets="related-links.ul.li__body">
              <fo:block xsl:use-attribute-sets="related-links.ul.li__content">
                <xsl:apply-templates select="."/>
              </fo:block>
            </fo:list-item-body>
          </fo:list-item>
        </xsl:for-each>
      </fo:list-block>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="ol-child-links">
    <xsl:variable name="children"
                  select="descendant::*[contains(@class, ' topic/link ')]
                                       [@role = ('child', 'descendant')]
                                       [parent::*/@collection-type = 'sequence']
                                       [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
    <xsl:if test="$children">
      <fo:list-block xsl:use-attribute-sets="related-links.ol">
        <xsl:for-each select="($children[generate-id(.) = generate-id(key('link', related-links:link(.))[1])])">
          <fo:list-item xsl:use-attribute-sets="related-links.ol.li">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="related-links.ol.li__label">
              <fo:block xsl:use-attribute-sets="related-links.ol.li__label__content">
                <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Ordered List Number'"/>
                  <xsl:with-param name="params">
                    <number>
                      <xsl:value-of select="position()"/>
                    </number>
                  </xsl:with-param>
                </xsl:call-template>
              </fo:block>
            </fo:list-item-label>
            <fo:list-item-body xsl:use-attribute-sets="related-links.ol.li__body">
              <fo:block xsl:use-attribute-sets="related-links.ol.li__content">
                <xsl:apply-templates select="."/>
              </fo:block>
            </fo:list-item-body>
          </fo:list-item>
        </xsl:for-each>
      </fo:list-block>
    </xsl:if>
  </xsl:template>

    <xsl:template name="getLinkScope" as="xs:string">
        <xsl:choose>
            <xsl:when test="ancestor-or-self::*[@scope][1]/@scope">
              <xsl:value-of select="ancestor-or-self::*[@scope][1]/@scope"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="'local'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/link ')]">
      <xsl:param name="topicType" as="xs:string?">
          <xsl:for-each select="ancestor::*[contains(@class,' topic/topic ')][1]">
              <xsl:call-template name="determineTopicType"/>
          </xsl:for-each>
      </xsl:param>
      <xsl:choose>
        <xsl:when test="(@role and not($includeRelatedLinkRoles = @role)) or
                        (not(@role) and not($includeRelatedLinkRoles = '#default'))"/>
        <xsl:when test="@role='child' and $chapterLayout='MINITOC' and
                        $topicType = ('topicChapter', 'topicAppendix', 'topicPart')">
          <!-- When a minitoc already links to children, do not add them here -->
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="processLink"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

  <xsl:template match="*[contains(@class,' topic/link ')][not(empty(@href) or @href='')]" mode="processLink">
    <xsl:variable name="destination" select="opentopic-func:getDestinationId(@href)"/>
    <xsl:variable name="element" select="key('key_anchor',$destination, $root)[1]" as="element()?"/>

    <xsl:variable name="referenceTitle" as="node()*">
        <xsl:apply-templates select="." mode="insertReferenceTitle">
            <xsl:with-param name="href" select="@href"/>
            <xsl:with-param name="titlePrefix" select="''"/>
            <xsl:with-param name="destination" select="$destination"/>
            <xsl:with-param name="element" select="$element"/>
        </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="linkScope" as="xs:string">
        <xsl:call-template name="getLinkScope"/>
    </xsl:variable>

    <fo:block xsl:use-attribute-sets="link">
        <fo:inline xsl:use-attribute-sets="link__content">
            <fo:basic-link>
                <xsl:call-template name="buildBasicLinkDestination">
                  <xsl:with-param name="scope" select="$linkScope"/>
                  <xsl:with-param name="href" select="@href"/>
                </xsl:call-template>
                <xsl:choose>
                  <xsl:when test="not($linkScope = 'external') and exists($referenceTitle)">
                    <xsl:copy-of select="$referenceTitle"/>
                  </xsl:when>
                  <xsl:when test="not($linkScope = 'external')">
                    <xsl:call-template name="insertPageNumberCitation">
                      <xsl:with-param name="isTitleEmpty" select="true()"/>
                      <xsl:with-param name="destination" select="$destination"/>
                      <xsl:with-param name="element" select="$element"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="*[contains(@class, ' topic/linktext ')]">
                    <xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="@href"/>
                  </xsl:otherwise>
                </xsl:choose>
            </fo:basic-link>
        </fo:inline>
      <xsl:if test="not($linkScope = 'external') and exists($referenceTitle)">
        <xsl:call-template name="insertPageNumberCitation">
          <xsl:with-param name="destination" select="$destination"/>
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:if>
      <xsl:call-template name="insertLinkShortDesc">
      <xsl:with-param name="destination" select="$destination"/>
      <xsl:with-param name="element" select="$element"/>
      <xsl:with-param name="linkScope" select="$linkScope"/>
    </xsl:call-template>
    </fo:block>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/link ')][empty(@href) or @href='']" mode="processLink">   
    <xsl:if test="*[contains(@class, ' topic/linktext ')]">
      <fo:block xsl:use-attribute-sets="link">
        <fo:inline>
          <xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/>
        </fo:inline>
        <xsl:if test="*[contains(@class, ' topic/desc ')]">
          <fo:block xsl:use-attribute-sets="link__shortdesc">
            <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
          </fo:block>
        </xsl:if>
      </fo:block>
    </xsl:if>
  </xsl:template>

    <xsl:template name="buildBasicLinkDestination">
        <xsl:param name="scope" select="@scope"/>
      <xsl:param name="format" select="@format"/>
        <xsl:param name="href" select="@href"/>
        <xsl:choose>
            <xsl:when test="(contains($href, '://') and not(starts-with($href, 'file://')))
            or starts-with($href, '/') or $scope = 'external' or not(empty($format) or  $format = 'dita')">
                <xsl:attribute name="external-destination">
                    <xsl:text>url('</xsl:text>
                    <xsl:value-of select="$href"/>
                    <xsl:text>')</xsl:text>
                </xsl:attribute>
            </xsl:when>
          <xsl:when test="$scope = 'peer'">
            <xsl:attribute name="internal-destination">
              <xsl:value-of select="$href"/>
            </xsl:attribute>
          </xsl:when>
          <xsl:when test="contains($href, '#')">
            <xsl:attribute name="internal-destination">
              <xsl:value-of select="opentopic-func:getDestinationId($href)"/>
            </xsl:attribute>
          </xsl:when>         
            <xsl:otherwise>
              <!-- Appears that topicmerge updates links so that this section will never be triggered; 
                   keeping $href as backup value in case something goes wrong. -->
              <xsl:attribute name="internal-destination">
                <xsl:value-of select="$href"/>
              </xsl:attribute>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="insertPageNumberCitation">
        <xsl:param name="isTitleEmpty" as="xs:boolean" select="false()"/>
        <xsl:param name="destination" as="xs:string"/>
        <xsl:param name="element" as="element()?"/>

        <xsl:choose>
            <xsl:when test="not($element) or ($destination = '')"/>
            <xsl:when test="$isTitleEmpty">
                <fo:inline>
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Page'"/>
                        <xsl:with-param name="params">
                            <pagenum>
                                <fo:inline>
                                    <fo:page-number-citation ref-id="{$destination}"/>
                                </fo:inline>
                            </pagenum>
                        </xsl:with-param>
                    </xsl:call-template>
                </fo:inline>
            </xsl:when>
            <xsl:otherwise>
                <fo:inline>
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'On the page'"/>
                        <xsl:with-param name="params">
                            <pagenum>
                                <fo:inline>
                                    <fo:page-number-citation ref-id="{$destination}"/>
                                </fo:inline>
                            </pagenum>
                        </xsl:with-param>
                    </xsl:call-template>
                </fo:inline>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/linktext ')]">
        <fo:inline xsl:use-attribute-sets="linktext">
            <xsl:apply-templates/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/linklist ')]">
        <fo:block xsl:use-attribute-sets="linklist">
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/linklist ')]/*[contains(@class,' topic/title ')]">
    <fo:block xsl:use-attribute-sets="linklist.title">
      <xsl:apply-templates select="." mode="customTitleAnchor"/>
      <xsl:apply-templates/>
    </fo:block>
  </xsl:template>

    <xsl:template match="*[contains(@class,' topic/linkinfo ')]">
        <fo:block xsl:use-attribute-sets="linkinfo">
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/linkpool ')]">
        <xsl:param name="topicType"/>
        <fo:block xsl:use-attribute-sets="linkpool">
            <xsl:apply-templates>
                <xsl:with-param name="topicType" select="$topicType"/>
            </xsl:apply-templates>
        </fo:block>
    </xsl:template>

    <xsl:function name="opentopic-func:getDestinationId">
        <xsl:param name="href"/>
        <xsl:call-template name="getDestinationIdImpl">
            <xsl:with-param name="href" select="$href"/>
        </xsl:call-template>
    </xsl:function>

    <xsl:template name="getDestinationIdImpl">
        <xsl:param name="href"/>
        
        <xsl:variable name="topic-id" select="substring-after($href, '#')"/>

        <xsl:variable name="element-id" select="substring-after($topic-id, '/')"/>

        <xsl:choose>
            <xsl:when test="$element-id = ''">
                <xsl:value-of select="$topic-id"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$element-id"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

<!-- Deprecated since 2.3 -->    
  <xsl:template name="brokenLinks">
  </xsl:template>
  
  <!-- Links with @type="topic" belong in no-name group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:get-group-priority"
                name="related-links:group-priority.topic" priority="-10"
                as="xs:integer">
    <xsl:call-template name="related-links:group-priority."/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:get-group"
                name="related-links:group.topic" priority="-10"
                as="xs:string">
    <xsl:call-template name="related-links:group."/>
  </xsl:template>
  
  <!-- Override no-name group wrapper template for HTML: output "Related Information" in a <linklist>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:result-group" name="related-links:group-result."
                as="element()?" priority="-10">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="exists($links)">
      <linklist class="- topic/linklist " outputclass="relinfo">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related information'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>
  
  <!-- Concepts have their own group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='concept']" mode="related-links:get-group"
                name="related-links:group.concept"
                as="xs:string">
    <xsl:text>concept</xsl:text>
  </xsl:template>
  
  <!-- Priority of concept group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='concept']" mode="related-links:get-group-priority"
                name="related-links:group-priority.concept"
                as="xs:integer">
    <xsl:sequence select="3"/>
  </xsl:template>
  
  <!-- Wrapper for concept group: "Related concepts" in a <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='concept']" mode="related-links:result-group"
                name="related-links:result.concept" as="element()?">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo relconcepts">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related concepts'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>
  
  <!-- References have their own group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='reference']" mode="related-links:get-group"
    name="related-links:group.reference"
    as="xs:string">
    <xsl:text>reference</xsl:text>
  </xsl:template>
  
  <!-- Priority of reference group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='reference']" mode="related-links:get-group-priority"
    name="related-links:group-priority.reference"
    as="xs:integer">
    <xsl:sequence select="1"/>
  </xsl:template>
  
  <!-- Reference wrapper for HTML: "Related reference" in <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='reference']" mode="related-links:result-group"
    name="related-links:result.reference" as="element()?">
    <xsl:param name="links"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo relref">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related reference'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>
  
  <!-- Tasks have their own group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:get-group"
                name="related-links:group.task"
                as="xs:string">
    <xsl:text>task</xsl:text>
  </xsl:template>
  
  <!-- Priority of task group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:get-group-priority"
                name="related-links:group-priority.task"
                as="xs:integer">
    <xsl:sequence select="2"/>
  </xsl:template>
  
  <!-- Task wrapper for HTML: "Related tasks" in <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:result-group"
                name="related-links:result.task" as="element()?">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo reltasks">
        <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related tasks'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
