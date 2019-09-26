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
    xmlns:rx="http://www.renderx.com/XSL/Extensions"
    version="2.0">

  <!-- common attribute sets -->

  <xsl:attribute-set name="common.border__top">
    <xsl:attribute name="border-before-style">solid</xsl:attribute>
    <xsl:attribute name="border-before-width">1pt</xsl:attribute>
    <xsl:attribute name="border-before-color">black</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="common.border__bottom">
    <xsl:attribute name="border-after-style">solid</xsl:attribute>
    <xsl:attribute name="border-after-width">1pt</xsl:attribute>
    <xsl:attribute name="border-after-color">black</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="common.border__right">
    <xsl:attribute name="border-end-style">solid</xsl:attribute>
    <xsl:attribute name="border-end-width">1pt</xsl:attribute>
    <xsl:attribute name="border-end-color">black</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="common.border__left">
    <xsl:attribute name="border-start-style">solid</xsl:attribute>
    <xsl:attribute name="border-start-width">1pt</xsl:attribute>
    <xsl:attribute name="border-start-color">black</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="common.border" use-attribute-sets="common.border__top common.border__right common.border__bottom common.border__left"/>

  <xsl:attribute-set name="base-font">
    <xsl:attribute name="font-size"><xsl:value-of select="$default-font-size"/></xsl:attribute>
  </xsl:attribute-set>

  <!-- titles -->
  <xsl:attribute-set name="common.title">
    <xsl:attribute name="font-family">sans-serif</xsl:attribute>
  </xsl:attribute-set>

  <!-- paragraph-like blocks -->
  <xsl:attribute-set name="common.block">
    <xsl:attribute name="space-before">0.6em</xsl:attribute>
    <xsl:attribute name="space-after">0.6em</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="common.link">
    <xsl:attribute name="color">blue</xsl:attribute>
  </xsl:attribute-set>

    <xsl:attribute-set name="__unresolved__conref">
        <xsl:attribute name="color">#CC3333</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="__fo__root" use-attribute-sets="base-font">
        <xsl:attribute name="font-family">serif</xsl:attribute>
        <!-- TODO: https://issues.apache.org/jira/browse/FOP-2409 -->
        <xsl:attribute name="xml:lang" select="translate($locale, '_', '-')"/>
        <xsl:attribute name="writing-mode" select="$writing-mode"/>
    </xsl:attribute-set>

    <xsl:attribute-set name="__force__page__count">
        <xsl:attribute name="force-page-count">
            <xsl:choose>
                <xsl:when test="/*[contains(@class, ' bookmap/bookmap ')]">
                    <xsl:value-of select="'even'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'auto'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:attribute>
    </xsl:attribute-set>

  <xsl:attribute-set name="page-sequence.cover" use-attribute-sets="__force__page__count">
  </xsl:attribute-set>

  <xsl:attribute-set name="page-sequence.frontmatter">
    <xsl:attribute name="format">i</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.notice" use-attribute-sets="__force__page__count page-sequence.frontmatter">
  </xsl:attribute-set>
    
  <xsl:attribute-set name="page-sequence.backmatter.notice" use-attribute-sets="__force__page__count">
    <xsl:attribute name="format">1</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.preface" use-attribute-sets="__force__page__count page-sequence.frontmatter">
  </xsl:attribute-set>

  <xsl:attribute-set name="page-sequence.toc" use-attribute-sets="__force__page__count page-sequence.frontmatter">
  </xsl:attribute-set>

  <xsl:attribute-set name="page-sequence.lot" use-attribute-sets="page-sequence.toc">
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.lof" use-attribute-sets="page-sequence.toc">
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.body" use-attribute-sets="__force__page__count">
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.part" use-attribute-sets="__force__page__count">
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.appendix" use-attribute-sets="__force__page__count">
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.glossary" use-attribute-sets="__force__page__count">
  </xsl:attribute-set>
  
  <xsl:attribute-set name="page-sequence.index" use-attribute-sets="__force__page__count">
  </xsl:attribute-set>

</xsl:stylesheet>
