/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2010 IBM Corporation
 *
 * See the accompanying LICENSE file for applicable license.
 */
package org.dita.dost.writer;

import org.dita.dost.TestUtils;
import org.dita.dost.exception.DITAOTException;
import org.dita.dost.index.IndexTerm;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import static org.dita.dost.TestUtils.assertHtmlEqual;

public class TestCHMIndexWriter {

    private static File tempDir;
    private static final File resourceDir = TestUtils.getResourceDir(TestCHMIndexWriter.class);
    private static final File expDir = new File(resourceDir, "exp");

    @BeforeClass
    public static void setUp() throws IOException, DITAOTException {
        tempDir = TestUtils.createTempDir(TestCHMIndexWriter.class);
    }

    @Test
    public void testWrite() throws DITAOTException, SAXException, IOException {
//        final Content content = new ContentImpl();
        final IndexTerm indexterm1 = new IndexTerm();
        indexterm1.setTermName("name1");
        indexterm1.setTermKey("indexkey1");
        final IndexTerm indexterm2 = new IndexTerm();
        indexterm2.setTermName("name2");
        indexterm2.setTermKey("indexkey2");
        indexterm1.addSubTerm(indexterm2);
        final List<IndexTerm> collection = new ArrayList<IndexTerm>();
        collection.add(indexterm1);
//        content.setCollection(collection);

        final CHMIndexWriter indexWriter = new CHMIndexWriter();
//        indexWriter.setContent(content);
        indexWriter.setTermList(collection);
        final File outFile = new File(tempDir, "index.hhk");
        indexWriter.write(outFile.getAbsoluteFile());

        assertHtmlEqual(new InputSource(new File(expDir, "index.hhk").toURI().toString()),
                new InputSource(outFile.toURI().toString()));
    }

    @AfterClass
    public static void tearDown() throws IOException {
        TestUtils.forceDelete(tempDir);
    }

}
