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

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:rx="http://www.renderx.com/XSL/Extensions"
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:comparer="com.idiominc.ws.opentopic.xsl.extension.CompareStrings"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
    exclude-result-prefixes="xs opentopic-index comparer rx opentopic-func">

  <xsl:template match="/" mode="index-postprocess">
    <fo:block xsl:use-attribute-sets="__index__label" id="{$id.index}">
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Index'"/>
      </xsl:call-template>
    </fo:block>
    <rx:flow-section column-count="2">
      <xsl:apply-templates select="//opentopic-index:index.groups" mode="index-postprocess"/>
    </rx:flow-section>
  </xsl:template>

  <xsl:template match="opentopic-index:index.entry" mode="index-postprocess">
    <xsl:variable name="value" select="@value"/>
    <xsl:choose>
      <xsl:when test="opentopic-index:index.entry">
        <fo:table rx:table-omit-initial-header="true" width="100%">
          <fo:table-header>
            <fo:table-row>
              <fo:table-cell>
                <fo:block xsl:use-attribute-sets="index-indents">
                  <xsl:if test="count(ancestor::opentopic-index:index.entry) > 0">
                    <xsl:attribute name="keep-together.within-page">always</xsl:attribute>
                  </xsl:if>
                  <xsl:variable name="following-idx" select="following-sibling::opentopic-index:index.entry[@value = $value and opentopic-index:refID]"/>
                  <xsl:if test="count(preceding-sibling::opentopic-index:index.entry[@value = $value]) = 0">
                    <xsl:apply-templates select="opentopic-index:formatted-value/node()"/>
                    <fo:inline font-style="italic">
                      <xsl:text> (</xsl:text>
                      <xsl:value-of select="$continuedValue"/>
                      <xsl:text>)</xsl:text>
                    </fo:inline>
                    <xsl:if test="$following-idx">
                      <xsl:text> </xsl:text>
                      <fo:index-page-citation-list>
                        <fo:index-key-reference ref-index-key="{$following-idx[1]/opentopic-index:refID/@value}"
                                                xsl:use-attribute-sets="__index__page__link"/>
                      </fo:index-page-citation-list>
                    </xsl:if>
                  </xsl:if>
                </fo:block>
              </fo:table-cell>
            </fo:table-row>
          </fo:table-header>
          <fo:table-body>
            <fo:table-row>
              <fo:table-cell>
                <fo:block xsl:use-attribute-sets="index-indents" keep-with-next="always">
                  <xsl:if test="count(ancestor::opentopic-index:index.entry) > 0">
                    <xsl:attribute name="keep-together.within-page">always</xsl:attribute>
                  </xsl:if>
                  <xsl:variable name="following-idx" select="following-sibling::opentopic-index:index.entry[@value = $value and opentopic-index:refID]"/>
                  <xsl:if test="count(preceding-sibling::opentopic-index:index.entry[@value = $value]) = 0">
                    <xsl:variable name="page-setting" select=" (ancestor-or-self::opentopic-index:index.entry/@no-page | ancestor-or-self::opentopic-index:index.entry/@start-page)[last()]"/>
                    <xsl:variable name="isNoPage" select=" $page-setting = 'true' and name($page-setting) = 'no-page' "/>
                    <xsl:variable name="refID" select="opentopic-index:refID/@value"/>
                    <xsl:choose>
                      <xsl:when test="opentopic-func:getIndexEntry($value,$refID)">
                        <xsl:apply-templates select="." mode="make-index-ref">
                          <xsl:with-param name="idxs" select="opentopic-index:refID"/>
                          <xsl:with-param name="inner-text" select="opentopic-index:formatted-value"/>
                          <xsl:with-param name="no-page" select="$isNoPage"/>
                        </xsl:apply-templates>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:variable name="isNormalChilds">
                          <xsl:for-each select="descendant::opentopic-index:index.entry">
                            <xsl:variable name="currValue" select="@value"/>
                            <xsl:variable name="currRefID" select="opentopic-index:refID/@value"/>
                            <xsl:if test="opentopic-func:getIndexEntry($currValue,$currRefID)">
                              <xsl:text>true </xsl:text>
                            </xsl:if>
                          </xsl:for-each>
                        </xsl:variable>
                        <xsl:if test="contains($isNormalChilds,'true ')">
                          <xsl:apply-templates select="." mode="make-index-ref">
                            <xsl:with-param name="inner-text" select="opentopic-index:formatted-value"/>
                            <xsl:with-param name="no-page" select="$isNoPage"/>
                          </xsl:apply-templates>
                        </xsl:if>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:if>
                </fo:block>
              </fo:table-cell>
            </fo:table-row>
          </fo:table-body>
          <fo:table-body>
            <fo:table-row>
              <fo:table-cell>
                <fo:block xsl:use-attribute-sets="index.entry__content">
                  <xsl:apply-templates mode="index-postprocess"/>
                </fo:block>
              </fo:table-cell>
            </fo:table-row>
          </fo:table-body>
        </fo:table>
      </xsl:when>
      <xsl:otherwise>
        <fo:block-container>
          <fo:block xsl:use-attribute-sets="index-indents">
            <xsl:if test="count(ancestor::opentopic-index:index.entry) > 0">
              <xsl:attribute name="keep-together.within-page">always</xsl:attribute>
            </xsl:if>
            <xsl:variable name="following-idx" select="following-sibling::opentopic-index:index.entry[@value = $value and opentopic-index:refID]"/>
            <xsl:if test="count(preceding-sibling::opentopic-index:index.entry[@value = $value]) = 0">
              <xsl:variable name="page-setting" select=" (ancestor-or-self::opentopic-index:index.entry/@no-page | ancestor-or-self::opentopic-index:index.entry/@start-page)[last()]"/>
            <xsl:variable name="isNoPage" select=" $page-setting = 'true' and name($page-setting) = 'no-page' "/>
              <xsl:apply-templates select="." mode="make-index-ref">
                <xsl:with-param name="idxs" select="opentopic-index:refID"/>
                <xsl:with-param name="inner-text" select="opentopic-index:formatted-value"/>
                <xsl:with-param name="no-page" select="$isNoPage"/>
              </xsl:apply-templates>
            </xsl:if>
          </fo:block>
        </fo:block-container>
        <!--fo:block xsl:use-attribute-sets="index.entry__content">
          <xsl:apply-templates mode="index-postprocess"/>
        </fo:block-->
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="make-index-ref">
    <xsl:param name="idxs" select="()"/>
    <xsl:param name="inner-text" select="()"/>
    <xsl:param name="no-page"/>
    <fo:block id="{generate-id(.)}" xsl:use-attribute-sets="index.term">
      <xsl:if test="empty(preceding-sibling::opentopic-index:index.entry)">
        <xsl:attribute name="keep-with-previous">always</xsl:attribute>
      </xsl:if>
      <fo:inline>
        <xsl:apply-templates select="$inner-text/node()"/>
      </fo:inline>
      <xsl:if test="$idxs">
        <xsl:for-each select="$idxs">
          <fo:inline id="{@value}"/>
        </xsl:for-each>
      </xsl:if>
      <xsl:if test="not($no-page)">
        <xsl:if test="$idxs">
          <xsl:copy-of select="$index.separator"/>
          <fo:inline>
            <fo:index-page-citation-list>
              <xsl:for-each select="$idxs">
                <fo:index-key-reference ref-index-key="{@value}" xsl:use-attribute-sets="__index__page__link"/>
              </xsl:for-each>
            </fo:index-page-citation-list>
          </fo:inline>
        </xsl:if>
      </xsl:if>
      <xsl:if test="@no-page = 'true'">
        <xsl:apply-templates select="opentopic-index:see-childs" mode="index-postprocess"/>
      </xsl:if>
      <xsl:if test="empty(opentopic-index:index.entry)">
        <xsl:apply-templates select="opentopic-index:see-also-childs" mode="index-postprocess"/>
      </xsl:if>
    </fo:block>
  </xsl:template>

</xsl:stylesheet>