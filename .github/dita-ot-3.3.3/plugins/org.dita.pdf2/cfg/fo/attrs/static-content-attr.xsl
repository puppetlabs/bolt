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
    version="2.0">

  <xsl:attribute-set name="odd__header">
    <xsl:attribute name="text-align">end</xsl:attribute>
    <xsl:attribute name="end-indent">10pt</xsl:attribute>
    <xsl:attribute name="space-before">10pt</xsl:attribute>
    <xsl:attribute name="space-before.conditionality">retain</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="even__header">
    <xsl:attribute name="start-indent">10pt</xsl:attribute>
    <xsl:attribute name="space-before">10pt</xsl:attribute>
    <xsl:attribute name="space-before.conditionality">retain</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="odd__footer">
    <xsl:attribute name="text-align">end</xsl:attribute>
    <xsl:attribute name="end-indent">10pt</xsl:attribute>
    <xsl:attribute name="space-after">10pt</xsl:attribute>
    <xsl:attribute name="space-after.conditionality">retain</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="even__footer">
    <xsl:attribute name="start-indent">10pt</xsl:attribute>
    <xsl:attribute name="space-after">10pt</xsl:attribute>
    <xsl:attribute name="space-after.conditionality">retain</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="pagenum">
    <xsl:attribute name="font-weight">bold</xsl:attribute>
  </xsl:attribute-set>


    <xsl:attribute-set name="__body__odd__footer" use-attribute-sets="odd__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__odd__footer__heading">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__odd__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__even__footer" use-attribute-sets="even__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__even__footer__heading">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__even__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__odd__header" use-attribute-sets="odd__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__odd__header__heading">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__odd__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__even__header" use-attribute-sets="even__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__even__header__heading">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__even__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__first__header" use-attribute-sets="odd__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__first__footer" use-attribute-sets="odd__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__first__header__heading">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__first__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__first__footer__heading">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__first__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__last__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__last__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__odd__footer" use-attribute-sets="odd__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__odd__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__even__footer" use-attribute-sets="even__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__even__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__odd__header" use-attribute-sets="odd__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__odd__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__even__header" use-attribute-sets="even__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__toc__even__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__odd__footer" use-attribute-sets="odd__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__odd__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__even__footer" use-attribute-sets="even__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__even__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__odd__header" use-attribute-sets="odd__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__odd__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__even__header" use-attribute-sets="even__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__index__even__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__body__footnote__separator">
        <xsl:attribute name="leader-pattern">rule</xsl:attribute>
        <xsl:attribute name="leader-length">25%</xsl:attribute>
        <xsl:attribute name="rule-thickness">0.5pt</xsl:attribute>
        <xsl:attribute name="rule-style">solid</xsl:attribute>
        <xsl:attribute name="color">black</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="__chapter__frontmatter__name__container">
        <xsl:attribute name="font-size">20pt</xsl:attribute>
        <xsl:attribute name="font-weight">bold</xsl:attribute>
        <xsl:attribute name="border-before-style">solid</xsl:attribute>
        <xsl:attribute name="border-after-style">solid</xsl:attribute>
        <xsl:attribute name="border-before-width">2pt</xsl:attribute>
        <xsl:attribute name="border-after-width">2pt</xsl:attribute>
        <xsl:attribute name="padding-top">10pt</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="__chapter__frontmatter__number__container">
        <xsl:attribute name="font-size">40pt</xsl:attribute>
        <xsl:attribute name="font-weight">bold</xsl:attribute>
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__odd__footer" use-attribute-sets="odd__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__odd__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__even__footer" use-attribute-sets="even__footer">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__even__footer__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__odd__header" use-attribute-sets="odd__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__odd__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__even__header" use-attribute-sets="even__header">
    </xsl:attribute-set>

    <xsl:attribute-set name="__glossary__even__header__pagenum" use-attribute-sets="pagenum">
    </xsl:attribute-set>

</xsl:stylesheet>