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
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:comparer="com.idiominc.ws.opentopic.xsl.extension.CompareStrings"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
    exclude-result-prefixes="xs opentopic-index comparer opentopic-func ot-placeholder">

  <xsl:variable name="index.continued-enabled" select="true()"/>

    <!-- *************************************************************** -->
    <!-- Create index templates                                          -->
    <!-- *************************************************************** -->

    <xsl:variable name="continuedValue">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Index Continued String'"/>
        </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="locale.lang" select="substring-before($locale, '_')"/>
    <xsl:variable name="locale.country" select="substring-after($locale, '_')"/>

    <xsl:variable name="warn-enabled" select="true()"/>

  <xsl:key name="index-key" match="opentopic-index:index.entry" use="@value"/>

  <xsl:variable name="index-entries">
            <xsl:apply-templates select="/" mode="index-entries"/>
  </xsl:variable>
  
  <xsl:variable name="index.separator">
    <xsl:text> </xsl:text>
  </xsl:variable>

    <xsl:template match="*[contains(@class,' topic/topic ')]" mode="index-entries">
        <xsl:variable name="id" select="ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id"/>
        <xsl:variable name="mapTopicref" select="key('map-id', $id)[1]" as="element()?"/>
        <xsl:if test="not(contains($mapTopicref/@otherprops, 'noindex'))">
            <xsl:apply-templates mode="index-entries"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="*[contains(@class,' topic/topic ')]" mode="index-postprocess">
        <xsl:variable name="id" select="ancestor-or-self::*[contains(@class, ' topic/topic ')][1]/@id"/>
        <xsl:variable name="mapTopicref" select="key('map-id', $id)[1]" as="element()?"/>
        <xsl:if test="not(contains($mapTopicref/@otherprops, 'noindex'))">
            <xsl:apply-templates mode="index-entries"/>
        </xsl:if>
    </xsl:template>

    <xsl:template match="opentopic-index:index.entry" mode="index-entries">
        <xsl:choose>
            <xsl:when test="opentopic-index:index.entry">
                <xsl:apply-templates mode="index-entries"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="opentopic-index:index.groups" mode="index-entries"/>

    <xsl:template match="*" priority="-1" mode="index-entries">
        <xsl:apply-templates mode="index-entries"/>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' topic/indexterm ')]">
    <xsl:apply-templates/>
  </xsl:template>

  <!--Following four templates handles index entry elements created by the index preprocessor task-->

    <xsl:template match="opentopic-index:index.groups"/>

  <xsl:template match="opentopic-index:index.entry[ancestor-or-self::opentopic-index:index.entry[@no-page='true'] and not(@single-page='true')]">
    <!--Skip index entries which shouldn't have a page numbering-->
    </xsl:template>

  <xsl:template match="opentopic-index:index.entry[@start-range='true']" priority="10">
      <!--Insert ranged index entry start marker-->
      <xsl:variable name="selfIDs" select="descendant-or-self::opentopic-index:index.entry[last()]/opentopic-index:refID/@value"/>
      <xsl:for-each select="$selfIDs">
          <xsl:variable name="selfID" select="."/>
          <xsl:variable name="followingMarkers" select="following::opentopic-index:index.entry[descendant-or-self::opentopic-index:index.entry[last()]/opentopic-index:refID/@value = $selfID]"/>
          <xsl:variable name="followingMarker" select="$followingMarkers[@end-range='true'][1]"/>
          <xsl:variable name="followingStartMarker" select="$followingMarkers[@start-range='true'][1]"/>
          <xsl:choose>
              <xsl:when test="not($followingMarker)and empty(ancestor-or-self::*[contains(@class, ' topic/prolog ')])">
                <xsl:call-template name="output-message">
                  <xsl:with-param name="id" select="'PDFX001W'"/>
                  <xsl:with-param name="msgparams">%1=<xsl:value-of select="$selfID"/></xsl:with-param>
                </xsl:call-template>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:choose>
                      <xsl:when test="$followingStartMarker and $followingStartMarker[following::*[generate-id() = generate-id($followingMarker)]]">
                        <xsl:call-template name="output-message">
                          <xsl:with-param name="id" select="'PDFX002W'"/>
                          <xsl:with-param name="msgparams">%1=<xsl:value-of select="$selfID"/></xsl:with-param>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise>
                          <fo:index-range-begin id="{../@indexid}_{generate-id()}" index-key="{../@indexid}" />
                      </xsl:otherwise>
                  </xsl:choose>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:for-each>
      <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="opentopic-index:index.entry[@end-range='true']" priority="10">
      <!--Insert ranged index entry end marker-->
      <xsl:variable name="selfIDs" select="descendant-or-self::opentopic-index:index.entry[last()]/opentopic-index:refID/@value"/>
      <xsl:for-each select="$selfIDs">
          <xsl:variable name="selfID" select="."/>
          <xsl:variable name="precMarkers" select="preceding::opentopic-index:index.entry[(@start-range or @end-range) and descendant-or-self::opentopic-index:index.entry[last()]/opentopic-index:refID/@value = $selfID]"/>
          <xsl:variable name="precMarker" select="$precMarkers[@start-range='true'][last()]"/>
          <xsl:variable name="precEndMarker" select="$precMarkers[@end-range='true'][last()]"/>
          <xsl:choose>
              <xsl:when test="not($precMarker)">
                <xsl:call-template name="output-message">
                  <xsl:with-param name="id" select="'PDFX007W'"/>
                  <xsl:with-param name="msgparams">%1=<xsl:value-of select="$selfID"/></xsl:with-param>
                </xsl:call-template>
              </xsl:when>
              <xsl:otherwise>
                  <xsl:choose>
                      <xsl:when test="$precEndMarker and $precEndMarker[preceding::*[generate-id() = generate-id($precMarker)]]">
                        <xsl:call-template name="output-message">
                          <xsl:with-param name="id" select="'PDFX003W'"/>
                          <xsl:with-param name="msgparams">%1=<xsl:value-of select="$selfID"/></xsl:with-param>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise>
                          <xsl:for-each select="$precMarker//opentopic-index:refID[@value = $selfID]/@value">
                              <fo:index-range-end ref-id="{../@indexid}_{generate-id()}" />
                          </xsl:for-each>
                      </xsl:otherwise>
                  </xsl:choose>
              </xsl:otherwise>
          </xsl:choose>
      </xsl:for-each>
      <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="opentopic-index:index.entry">
      <xsl:for-each select="opentopic-index:refID[last()]">
          <fo:inline index-key="{@indexid}"/>
      </xsl:for-each>
      <xsl:apply-templates/>
  </xsl:template>

    <xsl:template match="opentopic-index:*"/>
    <xsl:template match="opentopic-index:*" mode="preface" />
    <xsl:template match="opentopic-index:*" mode="index-postprocess"/>

  <xsl:template match="/" mode="index-postprocess">
    <fo:block xsl:use-attribute-sets="__index__label" id="{$id.index}">
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Index'"/>
      </xsl:call-template>
    </fo:block>
    <xsl:apply-templates select="//opentopic-index:index.groups" mode="index-postprocess"/>
  </xsl:template>

    <xsl:template match="*" mode="index-postprocess" priority="-1">
    <xsl:apply-templates mode="index-postprocess"/>
  </xsl:template>

  <xsl:template match="opentopic-index:index.groups" mode="index-postprocess">
    <xsl:apply-templates mode="index-postprocess"/>
  </xsl:template>

  <xsl:template match="opentopic-index:index.group[opentopic-index:index.entry]" mode="index-postprocess">
    <fo:block xsl:use-attribute-sets="index.entry" >
      <xsl:apply-templates mode="index-postprocess"/>
    </fo:block>
  </xsl:template>

  <xsl:template match="opentopic-index:label" mode="index-postprocess">
    <fo:block xsl:use-attribute-sets="__index__letter-group" id="{generate-id(.)}">
      <xsl:value-of select="."/>
    </fo:block>
  </xsl:template>

    <xsl:template match="opentopic-index:index.entry[not(opentopic-index:index.entry)]" mode="index-postprocess" priority="1">
        <xsl:variable name="page-setting" select=" (ancestor-or-self::opentopic-index:index.entry/@no-page | ancestor-or-self::opentopic-index:index.entry/@start-page)[last()]"/>
    <xsl:variable name="isNoPage" select=" $page-setting = 'true' and name($page-setting) = 'no-page' "/>
        <xsl:variable name="value" select="@value"/>
        <xsl:variable name="refID" select="opentopic-index:refID/@value"/>

        <xsl:if test="opentopic-func:getIndexEntry($value,$refID)">
            <xsl:apply-templates select="." mode="make-index-ref">
        <xsl:with-param name="idxs" select="opentopic-index:refID"/>
        <xsl:with-param name="inner-text" select="opentopic-index:formatted-value"/>
        <xsl:with-param name="no-page" select="$isNoPage"/>
      </xsl:apply-templates>
        </xsl:if>
    </xsl:template>

    <xsl:template match="opentopic-index:see-childs" mode="index-postprocess">
        <xsl:choose>
            <xsl:when test="parent::*[@no-page = 'true']">
                <fo:inline xsl:use-attribute-sets="index.see.label">
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Index See String'"/>
                    </xsl:call-template>
                </fo:inline>
                <fo:basic-link>
                    <xsl:attribute name="internal-destination">
                        <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-destination"/>
                    </xsl:attribute>
                    <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-value"/>
                </fo:basic-link>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="output-message">
                  <xsl:with-param name="id" select="'PDFX011E'"/>
                  <xsl:with-param name="msgparams">
                    <xsl:text>%1=</xsl:text><xsl:value-of select="if (following-sibling::opentopic-index:see-also-childs) then 'index-see-also' else 'indexterm'"/>
                    <xsl:text>;</xsl:text>
                    <xsl:text>%2=</xsl:text><xsl:value-of select="../@value"/>
                  </xsl:with-param>
                </xsl:call-template>
                <fo:block xsl:use-attribute-sets="index.entry__content">
                    <fo:inline xsl:use-attribute-sets="index.see-also.label">
                        <xsl:call-template name="getVariable">
                            <xsl:with-param name="id" select="'Index See Also String'"/>
                        </xsl:call-template>
                    </fo:inline>
                    <fo:basic-link>
                        <xsl:attribute name="internal-destination">
                            <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-destination"/>
                        </xsl:attribute>
                        <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-value"/>
                    </fo:basic-link>
                </fo:block>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:key name="opentopic-index:index.entry-def"
             match="opentopic-index:index.groups//opentopic-index:index.entry[empty(ancestor::opentopic-index:see-childs|ancestor::opentopic-index:see-also-childs)]"
             use="opentopic-index:refID/@value"/>

    <xsl:template match="opentopic-index:index.entry" mode="get-see-destination">
      <xsl:variable name="id" as="xs:string">
        <xsl:value-of>
          <xsl:apply-templates select="." mode="get-see-destination-id"/>
        </xsl:value-of>
      </xsl:variable>
      <xsl:variable name="ref" select="key('opentopic-index:index.entry-def', $id)[1]" as="element()?"/>
      <xsl:if test="exists($ref)">
        <xsl:value-of select="generate-id($ref[1])"/>
      </xsl:if>
    </xsl:template>

    <xsl:template match="opentopic-index:index.entry" mode="get-see-destination-id">
      <xsl:value-of select="concat(@value,':')"/>
      <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-destination-id"/>
    </xsl:template>

    <xsl:template match="opentopic-index:index.entry" mode="get-see-value">
        <fo:inline>
            <xsl:apply-templates select="opentopic-index:formatted-value/node()"/>
            <xsl:text> </xsl:text>
            <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-value"/>
        </fo:inline>
    </xsl:template>

    <xsl:template match="opentopic-index:see-also-childs" mode="index-postprocess">
        <fo:block xsl:use-attribute-sets="index.see-also-entry__content">
            <fo:inline xsl:use-attribute-sets="index.see-also.label">
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Index See Also String'"/>
                </xsl:call-template>
            </fo:inline>
            <fo:basic-link>
                <xsl:attribute name="internal-destination">
                    <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-destination"/>
                </xsl:attribute>
                <xsl:apply-templates select="opentopic-index:index.entry[1]" mode="get-see-value"/>
            </fo:basic-link>
        </fo:block>
    </xsl:template>

  <xsl:template match="opentopic-index:index.entry" mode="index-postprocess">
    <xsl:variable name="value" select="@value"/>
    
    <xsl:variable name="markerName" as="xs:string"
       select="concat('index-continued-', count(ancestor-or-self::opentopic-index:index.entry))"
    />

    <xsl:choose>
      <xsl:when test="opentopic-index:index.entry">
        <fo:table>
          <xsl:if test="$index.continued-enabled">
            <fo:table-header>
              <fo:retrieve-table-marker retrieve-class-name="{$markerName}"
                  retrieve-position-within-table="last-starting"
              />
            </fo:table-header>
          </xsl:if>
          <fo:table-body>
            <xsl:if test="$index.continued-enabled">
              <fo:marker marker-class-name="{$markerName}"/>
            </xsl:if>
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
                      <xsl:when test="$following-idx">
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
            <xsl:if test="$index.continued-enabled">
              <fo:marker marker-class-name="{$markerName}">
                <fo:table-row>
                  <fo:table-cell>
                    <fo:block xsl:use-attribute-sets="index-indents" keep-together="always">
                      <xsl:if test="true() or count(preceding-sibling::opentopic-index:index.entry[@value = $value]) = 0">
                        <xsl:apply-templates select="opentopic-index:formatted-value/node()"/>
                        <fo:inline font-style="italic">
                          <xsl:text> (</xsl:text>
                          <xsl:value-of select="$continuedValue"/>
                          <xsl:text>)</xsl:text>
                        </fo:inline>
                      </xsl:if>
                    </fo:block>
                  </fo:table-cell>
                </fo:table-row>
              </fo:marker>
            </xsl:if>
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
        <fo:block xsl:use-attribute-sets="index.entry__content">
          <xsl:apply-templates mode="index-postprocess"/>
        </fo:block>
      </xsl:otherwise>
    </xsl:choose>
 </xsl:template>

  <xsl:template name="make-index-ref">
    <xsl:param name="idxs" select="()"/>
    <xsl:param name="inner-text" select="()"/>
    <xsl:param name="no-page"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX066W'"/>
      <xsl:with-param name="msgparams">%1=make-index-ref</xsl:with-param>
    </xsl:call-template>
    <xsl:apply-templates select="." mode="make-index-ref">
      <xsl:with-param name="idxs" select="$idxs"/>
      <xsl:with-param name="inner-text" select="$inner-text"/>
      <xsl:with-param name="no-page" select="$no-page"/>
    </xsl:apply-templates>
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
      <!-- XXX: XEP has this, should base too? -->
      <!--
      <xsl:if test="$idxs">
        <xsl:for-each select="$idxs">
          <fo:inline id="{@value}"/>
        </xsl:for-each>
      </xsl:if>
      -->
      <xsl:if test="not($no-page)">
        <xsl:if test="$idxs">
          <xsl:copy-of select="$index.separator"/>
          <fo:index-page-citation-list>
            <xsl:for-each select="$idxs">
              <fo:index-key-reference ref-index-key="{@indexid}" xsl:use-attribute-sets="__index__page__link"/>
            </xsl:for-each>
          </fo:index-page-citation-list>
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

  <xsl:function name="opentopic-func:getIndexEntry">
    <xsl:param name="value"/>
    <xsl:param name="refID"/>

    <xsl:for-each select="$index-entries">
      <xsl:variable name="entries" select="key('index-key',$value)" as="element()*"/>
      <xsl:value-of select="$entries[opentopic-index:refID/@value = $refID]"/>
    </xsl:for-each>
  </xsl:function>

    <xsl:template name="createIndex">
        <xsl:if test="(//opentopic-index:index.groups//opentopic-index:index.entry) and (count($index-entries//opentopic-index:index.entry) &gt; 0)">
            <xsl:variable name="index">
                <xsl:choose>
                    <xsl:when test="$map//*[contains(@class,' bookmap/indexlist ')][@href]"/>
                    <xsl:when test="$map//*[contains(@class,' bookmap/indexlist ')]">
                        <xsl:apply-templates select="/" mode="index-postprocess"/>
                    </xsl:when>
                    <xsl:when test="/*[contains(@class,' map/map ')][not(contains(@class,' bookmap/bookmap '))]">
                        <xsl:apply-templates select="/" mode="index-postprocess"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:variable>
            <xsl:if test="count($index/*) > 0">
                <fo:page-sequence master-reference="index-sequence" xsl:use-attribute-sets="page-sequence.index">

                    <xsl:call-template name="insertIndexStaticContents"/>

                    <fo:flow flow-name="xsl-region-body">
                        <fo:marker marker-class-name="current-header">
                          <xsl:call-template name="getVariable">
                            <xsl:with-param name="id" select="'Index'"/>
                          </xsl:call-template>
                        </fo:marker>
                        <xsl:apply-templates select="." mode="customTopicMarker"/>
                        <xsl:copy-of select="$index"/>
                    </fo:flow>

                </fo:page-sequence>
            </xsl:if>
        </xsl:if>
    </xsl:template>

  <xsl:template match="ot-placeholder:indexlist[$retain-bookmap-order]">
    <xsl:call-template name="createIndex"/>
  </xsl:template>

    <xsl:template name="processIndexList">
        <fo:page-sequence master-reference="index-sequence" xsl:use-attribute-sets="page-sequence.index">

            <xsl:call-template name="insertIndexStaticContents"/>

            <fo:flow flow-name="xsl-region-body">
                <fo:block xsl:use-attribute-sets="__index__label" id="{$id.index}">
                    <xsl:apply-templates select="." mode="customTopicAnchor"/>
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Index'"/>
                    </xsl:call-template>
                </fo:block>

                <fo:block>
                    <xsl:apply-templates/>
                </fo:block>
            </fo:flow>

        </fo:page-sequence>
    </xsl:template>


</xsl:stylesheet>    