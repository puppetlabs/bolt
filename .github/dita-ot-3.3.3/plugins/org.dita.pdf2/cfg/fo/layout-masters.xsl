<?xml version="1.0"?>

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
    version="2.0">
    
    <xsl:template name="createLayoutMasters">
      <xsl:call-template name="createDefaultLayoutMasters"/>
    </xsl:template>

    <xsl:template name="createDefaultLayoutMasters">
        <fo:layout-master-set>
          <xsl:apply-templates select="." mode="create-page-masters"/>
          <xsl:apply-templates select="." mode="create-page-sequences"/> 
        </fo:layout-master-set>
    </xsl:template>
  
  <xsl:template match="/" mode="create-page-masters">
    <!-- Frontmatter simple masters -->
    <fo:simple-page-master master-name="front-matter-first" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body__frontmatter.odd"/>
    </fo:simple-page-master>
    
    <fo:simple-page-master master-name="front-matter-last" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body__frontmatter.even"/>
      <fo:region-before  region-name="last-frontmatter-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="last-frontmatter-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <xsl:if test="$mirror-page-margins">
      <fo:simple-page-master master-name="front-matter-even" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body__frontmatter.even"/>
        <fo:region-before region-name="even-frontmatter-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="even-frontmatter-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
    </xsl:if>
    
    <fo:simple-page-master master-name="front-matter-odd" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body__frontmatter.odd"/>
      <fo:region-before region-name="odd-frontmatter-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-frontmatter-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <!-- Backcover simple masters -->
    <xsl:if test="$generate-back-cover">
      <!--fo:simple-page-master master-name="back-cover-first" xsl:use-attribute-sets="simple-page-master">
                <fo:region-body xsl:use-attribute-sets="region-body__backcover.odd"/>
              </fo:simple-page-master-->
      
      <xsl:if test="$mirror-page-margins">
        <fo:simple-page-master master-name="back-cover-even" xsl:use-attribute-sets="simple-page-master">
          <fo:region-body xsl:use-attribute-sets="region-body__backcover.even"/>
          <fo:region-before region-name="even-back-cover-header" xsl:use-attribute-sets="region-before"/>
          <fo:region-after region-name="even-back-cover-footer" xsl:use-attribute-sets="region-after"/>
        </fo:simple-page-master>
      </xsl:if>
      
      <fo:simple-page-master master-name="back-cover-odd" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body__backcover.odd"/>
        <fo:region-before region-name="odd-back-cover-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="odd-back-cover-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
      
      <fo:simple-page-master master-name="back-cover-last" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body__backcover.even"/>
        <fo:region-before region-name="last-back-cover-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="last-back-cover-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
    </xsl:if>
    
    <!--TOC simple masters-->
    <xsl:if test="$mirror-page-margins">
      <fo:simple-page-master master-name="toc-even" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body.even"/>
        <fo:region-before region-name="even-toc-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="even-toc-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
    </xsl:if>
    
    <fo:simple-page-master master-name="toc-odd" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.odd"/>
      <fo:region-before region-name="odd-toc-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-toc-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <fo:simple-page-master master-name="toc-last" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.even"/>
      <fo:region-before region-name="even-toc-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="even-toc-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <fo:simple-page-master master-name="toc-first" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.odd"/>
      <fo:region-before region-name="odd-toc-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-toc-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <!--BODY simple masters-->
    <fo:simple-page-master master-name="body-first" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.odd"/>
      <fo:region-before region-name="first-body-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="first-body-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <xsl:if test="$mirror-page-margins">
      <fo:simple-page-master master-name="body-even" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body.even"/>
        <fo:region-before region-name="even-body-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="even-body-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
    </xsl:if>
    
    <fo:simple-page-master master-name="body-odd" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.odd"/>
      <fo:region-before region-name="odd-body-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-body-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <fo:simple-page-master master-name="body-last" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.even"/>
      <fo:region-before region-name="last-body-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="last-body-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <!--INDEX simple masters-->
    <fo:simple-page-master master-name="index-first" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body__index.odd"/>
      <fo:region-before region-name="odd-index-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-index-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <xsl:if test="$mirror-page-margins">
      <fo:simple-page-master master-name="index-even" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body__index.even"/>
        <fo:region-before region-name="even-index-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="even-index-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
    </xsl:if>
    
    <fo:simple-page-master master-name="index-odd" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body__index.odd"/>
      <fo:region-before region-name="odd-index-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-index-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <!--GLOSSARY simple masters-->
    <fo:simple-page-master master-name="glossary-first" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.odd"/>
      <fo:region-before region-name="odd-glossary-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-glossary-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
    
    <xsl:if test="$mirror-page-margins">
      <fo:simple-page-master master-name="glossary-even" xsl:use-attribute-sets="simple-page-master">
        <fo:region-body xsl:use-attribute-sets="region-body.even"/>
        <fo:region-before region-name="even-glossary-header" xsl:use-attribute-sets="region-before"/>
        <fo:region-after region-name="even-glossary-footer" xsl:use-attribute-sets="region-after"/>
      </fo:simple-page-master>
    </xsl:if>
    
    <fo:simple-page-master master-name="glossary-odd" xsl:use-attribute-sets="simple-page-master">
      <fo:region-body xsl:use-attribute-sets="region-body.odd"/>
      <fo:region-before region-name="odd-glossary-header" xsl:use-attribute-sets="region-before"/>
      <fo:region-after region-name="odd-glossary-footer" xsl:use-attribute-sets="region-after"/>
    </fo:simple-page-master>
  </xsl:template>
  
  <xsl:template match="/" mode="create-page-sequences">
    <xsl:call-template name="generate-page-sequence-master">
      <xsl:with-param name="master-name" select="'toc-sequence'"/>
      <xsl:with-param name="master-reference" select="'toc'"/>
    </xsl:call-template>
    <xsl:call-template name="generate-page-sequence-master">
      <xsl:with-param name="master-name" select="'body-sequence'"/>
      <xsl:with-param name="master-reference" select="'body'"/>
    </xsl:call-template>
    <xsl:call-template name="generate-page-sequence-master">
      <xsl:with-param name="master-name" select="'ditamap-body-sequence'"/>
      <xsl:with-param name="master-reference" select="'body'"/>
      <xsl:with-param name="first" select="false()"/>
      <xsl:with-param name="last" select="false()"/>
    </xsl:call-template>
    <xsl:call-template name="generate-page-sequence-master">
      <xsl:with-param name="master-name" select="'index-sequence'"/>
      <xsl:with-param name="master-reference" select="'index'"/>
      <xsl:with-param name="last" select="false()"/>
    </xsl:call-template>
    <xsl:call-template name="generate-page-sequence-master">
      <xsl:with-param name="master-name" select="'front-matter'"/>
      <xsl:with-param name="master-reference" select="'front-matter'"/>
    </xsl:call-template>
    <xsl:if test="$generate-back-cover">
      <xsl:call-template name="generate-page-sequence-master">
        <xsl:with-param name="master-name" select="'back-cover'"/>
        <xsl:with-param name="master-reference" select="'back-cover'"/>
        <xsl:with-param name="first" select="false()"/>
      </xsl:call-template>
    </xsl:if>
    <xsl:call-template name="generate-page-sequence-master">
      <xsl:with-param name="master-name" select="'glossary-sequence'"/>
      <xsl:with-param name="master-reference" select="'glossary'"/>
      <xsl:with-param name="last" select="false()"/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- Generate a page sequence master -->
  <xsl:template name="generate-page-sequence-master">
    <xsl:param name="master-name"/>
    <xsl:param name="master-reference"/>
    <xsl:param name="first" select="true()"/>
    <xsl:param name="last" select="true()"/>
    <fo:page-sequence-master master-name="{$master-name}">
      <fo:repeatable-page-master-alternatives>
        <xsl:if test="$first">
          <fo:conditional-page-master-reference master-reference="{$master-reference}-first"
                                                odd-or-even="odd"
                                                page-position="first"/>
        </xsl:if>
        <xsl:if test="$last">
          <fo:conditional-page-master-reference master-reference="{$master-reference}-last"
                                                odd-or-even="even"
                                                page-position="last"/>
                                            <!--blank-or-not-blank="blank"-->
        </xsl:if>
        <xsl:choose>
          <xsl:when test="$mirror-page-margins">
            <fo:conditional-page-master-reference master-reference="{$master-reference}-odd"
                                                  odd-or-even="odd"/>
            <fo:conditional-page-master-reference master-reference="{$master-reference}-even"
                                                  odd-or-even="even"/>
          </xsl:when>
          <xsl:otherwise>
            <fo:conditional-page-master-reference master-reference="{$master-reference}-odd"/>
          </xsl:otherwise>
        </xsl:choose>
      </fo:repeatable-page-master-alternatives>
    </fo:page-sequence-master>
    
  </xsl:template>
  
</xsl:stylesheet>